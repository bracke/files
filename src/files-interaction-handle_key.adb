separate (Files.Interaction)
   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result;
      Tree_Page_Rows    : Natural := 0)
   is
      --  Ctrl (Shift allowed for '+') without Alt/Meta drives keyboard zoom.
      Zoom_Modifier : constant Boolean :=
        Modifiers (Guikit.Input.Control_Key)
          and then not Modifiers (Guikit.Input.Alt_Key)
          and then not Modifiers (Guikit.Input.Meta_Key);
      Zoom_Chord    : constant Boolean :=
        Zoom_Modifier
          and then Key in Guikit.Input.Key_Equal
                        | Guikit.Input.Key_Minus
                        | Guikit.Input.Key_0;
      Zoom_Allowed  : constant Boolean :=
        not Files.Model.Input_Owning_Overlay_Is_Open (Model);
      --  A focused text field edits the text, which keeps its reading order
      --  in a mirrored window: its arrows move the caret as they point.
      Editing_Text  : constant Boolean :=
        Files.Model.Focus (Model) in Files.UI_Types.Focus_Path_Input | Files.UI_Types.Focus_Filter_Input
                                   | Files.UI_Types.Focus_Rename_Input | Files.UI_Types.Focus_Ownership_Input
        and then not Files.Model.Input_Owning_Overlay_Is_Open (Model);
      --  In a mirrored (right-to-left) window everything else is laid out
      --  the other way round -- the grid, the tree, menus, the toolbar's
      --  Back and Forward -- so Left and Right trade meanings.
      Laid_Out_Key  : constant Guikit.Input.Key_Code :=
        (if not Guikit.Mirroring.Mirrored_Layout or else Editing_Text then Key
         elsif Key = Guikit.Input.Key_Left then Guikit.Input.Key_Right
         elsif Key = Guikit.Input.Key_Right then Guikit.Input.Key_Left
         else Key);
   begin
      --  Start from a clean result so no flag leaks from a previous call when a
      --  caller reuses the same Result object across keystrokes.
      Result := (others => <>);
      --  Keyboard zoom is handled on this pure seam, not in the controller: the
      --  live font size is the shell's, not the model's. Ctrl+'=' / Ctrl+'+'
      --  grows, Ctrl+'-' shrinks, and Ctrl+0 resets it, through Apply_Zoom as
      --  Ctrl+wheel does. The window's next frame takes up the new size
      --  (Read_Window_State).
      if Zoom_Chord and then Zoom_Allowed then
         declare
            Old_Size : constant Positive := Settings.Font_Pixel_Size;
            New_Size : constant Positive :=
              (case Key is
                  when Guikit.Input.Key_Equal =>
                     Files.Settings.Clamp_Font_Pixel_Size (Old_Size + 1),
                  when Guikit.Input.Key_Minus =>
                     Files.Settings.Clamp_Font_Pixel_Size (Old_Size - 1),
                  when others =>
                     Files.Settings.Default_Font_Pixel_Size);
         begin
            Apply_Zoom (Model, Settings, Settings_Path, New_Size, Result);
            --  Drop any parallel '=' / '-' / '0' character event so a zoomed
            --  keystroke never leaks a glyph into a focused text field.
            Result.Clear_Pending_Text := True;
         end;
         return;
      end if;

      declare
         Before    : constant Files.Settings.Settings_Model := Settings;
         Before_UI : constant UI_State := UI_State_Of (Model);
         Ran       : Boolean;
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key
             (Model          => Model,
              Settings       => Settings,
              Key            => Laid_Out_Key,
              Action         => Files.Events.Translate_Key (Laid_Out_Key, Modifiers),
              Modifiers      => Modifiers,
              Tree_Page_Rows => Tree_Page_Rows);
      begin
         case Outcome.Activation is
            --  Enter on an overlay's highlighted control: completed by the
            --  routine a click on that control runs, so both report the
            --  settings change, and run a menu row's command, the same way.
            when Files.Controller.Choose_Label =>
               Apply_Label (Model, Settings, Settings_Path, Outcome.Label, Result);
            when Files.Controller.Run_Menu_Row =>
               Apply_Context_Menu_Command (Model, Settings, Settings_Path, Outcome.Command, Modifiers, Result);
            when Files.Controller.No_Activation =>
               --  A view / info-pane change from the keyboard (Ctrl+1..4) has
               --  already run inside Handle_Key; Conclude writes it back, and
               --  applies a settings shortcut (or Enter in the palette).
               Conclude (Model, Settings, Settings_Path, Outcome, Before, Before_UI, Result, Ran);
               --  A settings shortcut (or Enter in the palette) ran; the
               --  shell drops any parallel character event.
               Result.Clear_Pending_Text := Ran;
         end case;
      end;

      --  Space is a reserved grid shortcut (Quick Look), not a type-ahead
      --  character: when the grid owns the keyboard, drop the parallel space
      --  character event so it never leaks into type-ahead. A space typed into a
      --  focused text field keeps its character event and types a space; one
      --  that flipped a settings toggle or choice is dropped like the grid's.
      if Key = Guikit.Input.Key_Space
        and then (Files.Model.Focus (Model) = Files.UI_Types.Focus_None
                  or else (Files.Model.Focus (Model) = Files.UI_Types.Focus_Settings_Input
                           and then Files.Model.Settings_Pane.Focused_Kind (Model) in
                             Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice))
      then
         Result.Clear_Pending_Text := True;
      end if;

      --  A reserved zoom chord is consumed even when a modal overlay blocks
      --  the zoom itself, so its parallel character event cannot type "=" into
      --  an overlay text field.
      if Zoom_Chord then
         Result.Clear_Pending_Text := True;
      end if;

      Finish_Dispatch (Model, Settings, Settings_Path, Result);
   end Handle_Key;
