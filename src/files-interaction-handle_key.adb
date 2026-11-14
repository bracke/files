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
      --  Post-controller work must belong to the overlay that owned this key
      --  when dispatch began.  A command executed by one overlay can open a
      --  different overlay, which must not consume the same keypress again.
      Label_Picker_At_Entry : constant Boolean :=
        Files.Model.Label_Picker.Is_Open (Model);
      Context_Menu_At_Entry : constant Boolean :=
        Files.Model.Context_Menu.Is_Open (Model);
      Tree_Pick_At_Entry : constant Boolean :=
        Files.Model.Tree_Panel.Pick_Is_Active (Model);
   begin
      --  Start from a clean result so no flag leaks from a previous call when a
      --  caller reuses the same Result object across keystrokes.
      Result := (others => <>);
      --  Keyboard zoom is handled on this pure seam, not in the controller: the
      --  live font size is the shell's, not the model's. Ctrl+'=' / Ctrl+'+'
      --  grows, Ctrl+'-' shrinks, and Ctrl+0 resets it, through Apply_Zoom as
      --  Ctrl+wheel does. The shell's font-size sync and glyph rebuild then run
      --  through Apply_Interaction_Result.
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
         Before  : constant Files.Settings.Settings_Model := Settings;
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key
             (Model          => Model,
              Settings       => Settings,
              Settings_Path  => Settings_Path,
              Key            => Key,
              Modifiers      => Modifiers,
              Tree_Page_Rows => Tree_Page_Rows);
      begin
         Observe_Controller_Outcome (Outcome, Result);
         declare
            Ran : constant Boolean := Ran_Settings_Command (Outcome.Command, Outcome, Before, Settings);
         begin
            --  A view / info-pane change from the keyboard (Ctrl+1..4) has
            --  already run inside Handle_Key; the tail writes it back.
            Finish_Settings_Command
              (Model, Settings, Settings_Path, Outcome.Command, Before,
               Observe => Ran,
               Result  => Result);
            --  The controller applied a settings shortcut (or Enter in the
            --  palette); the shell drops any parallel character event.
            if Ran then
               Result.Clear_Pending_Text := True;
            end if;
         end;
      end;

      --  A keyboard Enter on the open label picker applies the highlighted
      --  swatch to the selection through Apply_Label, the routine the mouse
      --  Label_Picker_Choice_Input_Action uses, so both report the settings change
      --  the same way.
      if Label_Picker_At_Entry
        and then Files.Model.Label_Picker.Is_Open (Model)
        and then Key = Guikit.Input.Key_Return
      then
         Apply_Label (Model, Settings, Settings_Path, Files.Model.Label_Picker.Highlight_Color (Model), Result);
      end if;

      --  A keyboard Enter on the open context menu runs the highlighted command
      --  through Apply_Context_Menu_Command, exactly as clicking that row does
      --  (it also carries the zoom and settings follow-ups only this layer
      --  reports).
      if Context_Menu_At_Entry
        and then Files.Model.Context_Menu.Is_Open (Model)
        and then Key = Guikit.Input.Key_Return
      then
         declare
            use type Files.Commands.Context_Menu_Row_Kind;
            Rows      : constant Files.Commands.Context_Menu_Rows :=
              Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu.Target_Of (Model));
            Highlight : constant Natural := Files.Model.Context_Menu.Highlight (Model);
         begin
            if Highlight in 1 .. Rows.Count
              and then Rows.Rows (Highlight).Kind = Files.Commands.Menu_Command
            then
               Apply_Context_Menu_Command
                 (Model, Settings, Settings_Path, Rows.Rows (Highlight).Command,
                  Modifiers, Result);
            else
               --  Nothing highlighted (a mouse-opened menu not yet arrowed): a
               --  bare Enter just dismisses it.
               Files.Model.Context_Menu.Close (Model);
            end if;
         end;
      end if;

      --  A keyboard Enter with the destination-pick tree active confirms it: copy
      --  or move the captured sources into the highlighted directory, then close
      --  the sidebar, through the routine the picker's Confirm button uses.
      if Tree_Pick_At_Entry
        and then Files.Model.Tree_Panel.Pick_Is_Active (Model)
        and then Key = Guikit.Input.Key_Return
      then
         Confirm_Tree_Pick (Model, Settings);
      end if;

      --  Space is a reserved grid shortcut (Quick Look), not a type-ahead
      --  character: when the grid owns the keyboard, drop the parallel space
      --  character event so it never leaks into type-ahead. A space typed into a
      --  focused text field keeps its character event and types a space; one
      --  that flipped a settings toggle or choice is dropped like the grid's.
      if Key = Guikit.Input.Key_Space
        and then (Files.Model.Focus (Model) = Files.Types.Focus_None
                  or else (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input
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
