separate (Files.Controller)
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
   is
      Action : constant Files.Events.Input_Action := Files.Events.Translate_Key (Key, Modifiers);

      function Control_Only return Boolean is
      begin
         return Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Shift_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key);
      end Control_Only;
   begin
      --  While a long paste is running the progress overlay owns the keyboard:
      --  Escape requests cancellation (already-copied files are kept) and every
      --  other key is swallowed so no command runs behind the modal-lite panel.
      if Files.Model.Paste_Execution_Is_Active (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Operations.Cancel_Paste_Execution (Model);
            declare
               Finalized : constant Files.Operations.Operation_Result :=
                 Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            begin
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Finalized);
            end;
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      --  While the paste-conflict dialog is open it owns the keyboard: Escape
      --  cancels the whole paste and every other key is swallowed so no command
      --  runs behind the modal.
      if Files.Model.Paste_Conflict_Is_Active (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            declare
               Cancelled : constant Files.Operations.Operation_Result :=
                 Files.Operations.Resolve_Paste_Conflict
                   (Model     => Model,
                    Settings  => Settings,
                    Choice    => Files.Operations.Choice_Cancel,
                    Apply_All => False);
            begin
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Cancelled);
            end;
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      --  While the Quick Look overlay is open it owns the keyboard: Escape or
      --  Space close it; the grid-navigation keys (arrows, Home/End, Page Up/Down)
      --  move the selection underneath -- just as they would in the file grid --
      --  and re-preview the newly selected item, so the user can flip through files
      --  without leaving Quick Look. Every other key is swallowed so nothing behind
      --  the modal-lite preview reacts.
      if Files.Model.Quick_Look_Is_Open (Model) then
         if (Key = Guikit.Input.Key_Escape or else Key = Guikit.Input.Key_Space)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            Files.Model.Close_Quick_Look (Model);
            return Successful_Command_Result (Files.Commands.Toggle_Quick_Look_Command);
         elsif Modifiers = Guikit.Input.No_Modifiers
           and then (Key = Guikit.Input.Key_Up or else Key = Guikit.Input.Key_Down
                     or else Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Right
                     or else Key = Guikit.Input.Key_Home or else Key = Guikit.Input.Key_End
                     or else Key = Guikit.Input.Key_Page_Up or else Key = Guikit.Input.Key_Page_Down)
         then
            declare
               Old_Index : constant Natural := Files.Model.Selected_Index (Model);
            begin
               case Key is
                  when Guikit.Input.Key_Up =>
                     Files.Model.Move_Selection (Model, Guikit.Input.Move_Up);
                  when Guikit.Input.Key_Down =>
                     Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
                  when Guikit.Input.Key_Left =>
                     Files.Model.Move_Selection (Model, Guikit.Input.Move_Left);
                  when Guikit.Input.Key_Right =>
                     Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
                  when Guikit.Input.Key_Home =>
                     Files.Model.Select_First_Visible (Model);
                  when Guikit.Input.Key_End =>
                     Files.Model.Select_Last_Visible (Model);
                  when Guikit.Input.Key_Page_Up =>
                     Files.Model.Move_Selection_By_Page (Model, Grid_Page_Rows, False);
                  when Guikit.Input.Key_Page_Down =>
                     Files.Model.Move_Selection_By_Page (Model, Grid_Page_Rows, True);
                  when others =>
                     null;
               end case;
               if Files.Model.Selected_Index (Model) = Old_Index then
                  return Make_Result (Controller_Ignored);
               end if;
               Files.Model.Open_Quick_Look
                 (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
               return Make_Result (Controller_Selection_Moved);
            end;
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Command_Palette (Model);
            return Make_Result (Controller_Palette_Updated, Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, -1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, 1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, -1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, 1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Select_First (Model);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Select_Last (Model);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Page_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Page (Model, Down => False);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Page_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Page (Model, Down => True);
            return Make_Result (Controller_Palette_Updated);
         end if;
      end if;

      if Files.Model.Root_Selector_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Root_Selector (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            return Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Left);
         elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Right);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Up);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Down);
         elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Jump_Result (Model, 1);
         elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Jump_Result (Model, Files.Model.Root_Count (Model));
         elsif Action.Kind = Files.Events.Command_Input_Action
           and then Action.Command = Files.Commands.Open_Command_Palette_Command
         then
            null;
         else
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      --  These grid popups own the keyboard while open: Escape closes them, and
      --  every other key is consumed so it does not leak through to move the
      --  selection on the grid behind. Without this a keyboard user who opened
      --  one from the command palette was trapped -- Escape did nothing and the
      --  arrows moved the hidden grid. (They are still mouse-driven for choosing
      --  a row; per-overlay arrow navigation is a separate enhancement.)
      if Files.Model.Label_Picker_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Label_Picker (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif (Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Up)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            Files.Model.Move_Label_Picker_Highlight (Model, -1);
            return Make_Result (Controller_Selection_Moved);
         elsif (Key = Guikit.Input.Key_Right or else Key = Guikit.Input.Key_Down)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            Files.Model.Move_Label_Picker_Highlight (Model, 1);
            return Make_Result (Controller_Selection_Moved);
         else
            --  Enter is applied on the Interaction seam (choosing a label writes
            --  settings, which the read-only controller cannot); every other key
            --  is consumed so the grid behind the picker stays put.
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      if Files.Model.Context_Menu_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Context_Menu (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif (Key = Guikit.Input.Key_Up or else Key = Guikit.Input.Key_Down)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            declare
               use type Files.Commands.Context_Menu_Row_Kind;
               Rows : constant Files.Commands.Context_Menu_Rows :=
                 Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu_Target_Of (Model));
               Direction : constant Integer := (if Key = Guikit.Input.Key_Up then -1 else 1);
               Current   : constant Natural := Files.Model.Context_Menu_Highlight (Model);
               Index     : Integer :=
                 (if Current /= 0 then Current
                  elsif Direction > 0 then 0
                  else Rows.Count + 1);
               Landed    : Natural := 0;
            begin
               --  Step to the next enabled command row, skipping separators and
               --  disabled entries; stop (leaving the highlight put) at the ends.
               loop
                  Index := Index + Direction;
                  exit when Index < 1 or else Index > Rows.Count;
                  if Rows.Rows (Index).Kind = Files.Commands.Menu_Command
                    and then Files.Commands.Is_Enabled (Rows.Rows (Index).Command, Model)
                  then
                     Landed := Index;
                     exit;
                  end if;
               end loop;
               if Landed /= 0 then
                  Files.Model.Set_Context_Menu_Highlight (Model, Landed);
               end if;
               return Make_Result (Controller_Selection_Moved);
            end;
         else
            --  Enter is applied on the Interaction seam (running a menu command
            --  needs the settings path); every other key is consumed so the grid
            --  behind the menu stays put.
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      if Files.Model.Sort_Menu_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Sort_Menu (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Move_Sort_Menu_Highlight (Model, -1);
            return Make_Result (Controller_Selection_Moved);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Move_Sort_Menu_Highlight (Model, 1);
            return Make_Result (Controller_Selection_Moved);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            declare
               use type Files.Model.Sort_Field;
               Field   : constant Files.Model.Sort_Field :=
                 Files.Model.Sort_Menu_Highlight_Field (Model);
               Command : constant Files.Commands.Command_Id :=
                 (case Field is
                     when Files.Model.Sort_Name    => Files.Commands.Sort_By_Name_Command,
                     when Files.Model.Sort_Size    => Files.Commands.Sort_By_Size_Command,
                     when Files.Model.Sort_Type    => Files.Commands.Sort_By_Type_Command,
                     when Files.Model.Sort_Created => Files.Commands.Sort_By_Created_Command,
                     when Files.Model.Sort_Changed => Files.Commands.Sort_By_Changed_Command);
            begin
               Files.Model.Close_Sort_Menu (Model);
               return Execute_Command (Command, Model, Settings, Modifiers);
            end;
         else
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      --  Only the modal destination-pick tree owns the keyboard; the tree shown
      --  as an ordinary side panel leaves grid navigation alone. Escape cancels
      --  the pick and closes the panel the Copy/Move-To command opened.
      if Files.Model.Tree_Pick_Is_Active (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Clear_Tree_Pick (Model);
            Files.Model.Close_Tree_Panel (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key in Guikit.Input.Key_Up | Guikit.Input.Key_Down
                    | Guikit.Input.Key_Left | Guikit.Input.Key_Right
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            declare
               Rows    : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
                 Files.Model.Tree_Visible_Rows (Model);
               Target  : constant String := Files.Model.Tree_Pick_Target (Model);
               Current : Natural := 0;
            begin
               if Rows.Is_Empty then
                  return Make_Result (Controller_Ignored);
               end if;
               for Idx in Rows.First_Index .. Rows.Last_Index loop
                  if To_String (Rows (Idx).Path) = Target then
                     Current := Idx;
                     exit;
                  end if;
               end loop;
               if Current = 0 then
                  --  No destination highlighted yet: the first arrow lands on the
                  --  first row so the rest of the navigation has an anchor.
                  Files.Model.Set_Tree_Pick_Target
                    (Model, To_String (Rows (Rows.First_Index).Path));
                  return Make_Result (Controller_Selection_Moved);
               end if;

               case Key is
                  when Guikit.Input.Key_Up =>
                     if Current > Rows.First_Index then
                        Files.Model.Set_Tree_Pick_Target
                          (Model, To_String (Rows (Current - 1).Path));
                     end if;
                  when Guikit.Input.Key_Down =>
                     if Current < Rows.Last_Index then
                        Files.Model.Set_Tree_Pick_Target
                          (Model, To_String (Rows (Current + 1).Path));
                     end if;
                  when Guikit.Input.Key_Right =>
                     if Rows (Current).Has_Children and then not Rows (Current).Expanded then
                        --  Expand the folder (loading its children if needed),
                        --  reusing the mouse toggle path.
                        return Handle_Tree_Click
                          (Model, Settings, Rows (Current).Node_Index, Toggle => True);
                     elsif Rows (Current).Expanded and then Current < Rows.Last_Index then
                        Files.Model.Set_Tree_Pick_Target
                          (Model, To_String (Rows (Current + 1).Path));
                     end if;
                  when Guikit.Input.Key_Left =>
                     if Rows (Current).Expanded then
                        return Handle_Tree_Click
                          (Model, Settings, Rows (Current).Node_Index, Toggle => True);
                     else
                        --  Step out to the parent: the nearest earlier, shallower row.
                        for Up_Idx in reverse Rows.First_Index .. Current - 1 loop
                           if Rows (Up_Idx).Depth < Rows (Current).Depth then
                              Files.Model.Set_Tree_Pick_Target
                                (Model, To_String (Rows (Up_Idx).Path));
                              exit;
                           end if;
                        end loop;
                     end if;
                  when others =>
                     null;
               end case;
               return Make_Result (Controller_Selection_Moved);
            end;
         else
            --  Enter confirms the pick on the Interaction seam (running the copy or
            --  move needs the settings path); every other key is consumed.
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      --  Shift+F10 opens the context menu on the current selection -- the
      --  keyboard equivalent of a right-click -- so its rows are reachable and
      --  navigable without a mouse. (The Menu/Application key is not in the key
      --  set; Shift+F10 is its universal stand-in.)
      if Key = Guikit.Input.Key_F10
        and then Modifiers (Guikit.Input.Shift_Key)
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
      then
         if Files.Model.Selected_Count (Model) > 0 then
            Files.Model.Open_Context_Menu
              (Model, 0, 0, Files.Model.Context_Menu_Item, Files.Model.Selected_Index (Model));
         else
            Files.Model.Open_Context_Menu (Model, 0, 0, Files.Model.Context_Menu_Empty);
         end if;
         return Make_Result (Controller_Selection_Moved);
      end if;

      --  Tab / Shift+Tab cycle keyboard focus around the main-view controls:
      --  grid -> path input -> filter -> grid, and Shift+Tab reverses. Each field
      --  keeps its direct shortcut (Ctrl+L, Ctrl+F, Escape back to the grid); this
      --  adds the conventional ring. Only these three focus states take part --
      --  rename, palette, settings and ownership focus have their own handling,
      --  and the settings pane's Ctrl+Tab is untouched (this ignores Ctrl/Alt).
      if Key = Guikit.Input.Key_Tab
        and then not Modifiers (Guikit.Input.Control_Key)
        and then not Modifiers (Guikit.Input.Alt_Key)
        and then Files.Model.Focus (Model) in
          Files.Types.Focus_None
            | Files.Types.Focus_Path_Input
            | Files.Types.Focus_Filter_Input
      then
         declare
            Backward : constant Boolean := Modifiers (Guikit.Input.Shift_Key);
         begin
            case Files.Model.Focus (Model) is
               when Files.Types.Focus_None =>
                  if Backward then
                     Files.Model.Focus_Filter_Input (Model);
                  else
                     Files.Model.Focus_Path_Input (Model);
                  end if;
               when Files.Types.Focus_Path_Input =>
                  if Backward then
                     Files.Model.Cancel_Focus_Or_Edit (Model);
                  else
                     Files.Model.Focus_Filter_Input (Model);
                  end if;
               when Files.Types.Focus_Filter_Input =>
                  if Backward then
                     Files.Model.Focus_Path_Input (Model);
                  else
                     Files.Model.Cancel_Focus_Or_Edit (Model);
                  end if;
               when others =>
                  null;
            end case;
            return Make_Result (Controller_Text_Updated);
         end;
      end if;

      if Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input then
         if Files.Model.Settings_Is_Capturing (Model) then
            --  A Shortcut row is armed: every key is a chord to capture, not a
            --  navigation or shortcut, until the capture ends.
            return Capture_Settings_Shortcut (Model, Key, Modifiers);
         elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Toggle_Settings_Pane (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Settings_Move_Focus (Model, -1);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Settings_Move_Focus (Model, 1);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif (Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Right)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            --  Left/Right cycle the focused toggle/choice or step a number (a
            --  no-op on text fields); the emitted change is applied to the draft.
            Files.Model.Settings_Cycle_Choice (Model, Forward => Key = Guikit.Input.Key_Right);
            return Applied_Settings_Change (Model);
         elsif Key = Guikit.Input.Key_Tab
           and then Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key)
         then
            --  Ctrl+Tab / Ctrl+Shift+Tab switch between the section tabs -- the
            --  keyboard equivalent of clicking the tab switcher.
            Cycle_Settings_Section (Model, Forward => not Modifiers (Guikit.Input.Shift_Key));
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            --  Enter on a focused Shortcut row arms press-to-capture (the
            --  keyboard equivalent of clicking it); otherwise fall through to the
            --  general Return handling below.
            Files.Model.Settings_Begin_Capture (Model);
            if Files.Model.Settings_Is_Capturing (Model) then
               return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
            end if;
         end if;
      end if;

      if Key = Guikit.Input.Key_Return then
         if Modifiers = Guikit.Input.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Files.Model.Focus (Model) = Files.Types.Focus_None then
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
         end if;
      elsif Key = Guikit.Input.Key_Backspace
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Backward (Model);
      elsif Key = Guikit.Input.Key_Delete
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Forward (Model);
      elsif Key = Guikit.Input.Key_Left
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Left)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position
              (Model, Previous_Word_Boundary (Focused_Text (Model), Old_Position));
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Right
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Right)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position
              (Model, Next_Word_Boundary (Focused_Text (Model), Old_Position));
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Backspace
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Backward (Model);
      elsif Key = Guikit.Input.Key_Delete
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Forward (Model);
      elsif Key = Guikit.Input.Key_Left
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Left)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Right
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Right);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Home
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  Plain Home in the file grid selects the first visible item. This has
         --  no modifier, so it never collides with Alt+Home = navigate home.
         return First_Selection_Result (Model);
      elsif Key = Guikit.Input.Key_End
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  Plain End in the file grid selects the last visible item.
         return Last_Selection_Result (Model);
      elsif Key = Guikit.Input.Key_Home
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Set_All_Carets_Home (Model)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position (Model, 0);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_End
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Set_All_Carets_End (Model)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position (Model, Focused_Text (Model)'Length);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Page_Up
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  With the info pane open Page Up scrolls it; over the file grid it
         --  pages the selection up by a page (like the arrow keys move it).
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, -10);
         else
            return Page_Selection_Result (Model, Down => False);
         end if;
      elsif Key = Guikit.Input.Key_Page_Down
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, 10);
         else
            return Page_Selection_Result (Model, Down => True);
         end if;
      elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         if Files.Model.Focus (Model) = Files.Types.Focus_None
           and then not Files.Model.Rename_Is_Active (Model)
           and then not Files.Model.Temporary_Item_Is_Active (Model)
         then
            if Files.Model.Settings_Pane_Is_Open (Model) then
               Files.Model.Toggle_Settings_Pane (Model);
               return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
            else
               return Make_Result (Controller_Ignored, Files.Commands.Close_Command_Palette_Command);
            end if;
         else
            Files.Model.Cancel_Focus_Or_Edit (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         end if;
      end if;

      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Action.Command = Files.Commands.Toggle_Quick_Look_Command
              and then Files.Model.Focus (Model) /= Files.Types.Focus_None
            then
               --  Space is the Quick Look shortcut only when the grid owns the
               --  keyboard. With a text field focused it is a typed space, so
               --  ignore the shortcut and let the character event handle it.
               return Make_Result (Controller_Ignored);
            end if;
            return Execute_Command (Action.Command, Model, Settings, Modifiers);
         when Files.Events.Selection_Input_Action =>
            if Files.Model.Focus (Model) = Files.Types.Focus_None
              and then not Files.Model.Settings_Pane_Is_Open (Model)
            then
               declare
                  Old_Index : constant Natural := Files.Model.Selected_Index (Model);
                  Old_Count : constant Natural := Files.Model.Selected_Count (Model);
                  Anchor    : Natural := Old_Index;
               begin
                  if Action.Range_Selection and then Old_Count > 1 then
                     declare
                        First_Selected : Natural := 0;
                        Last_Selected  : Natural := 0;
                     begin
                        for Index in 1 .. Files.Model.Visible_Count (Model) loop
                           if Files.Model.Is_Selected (Model, Positive (Index)) then
                              if First_Selected = 0 then
                                 First_Selected := Index;
                              end if;
                              Last_Selected := Index;
                           end if;
                        end loop;

                        if Old_Index = Last_Selected then
                           Anchor := First_Selected;
                        elsif Old_Index = First_Selected then
                           Anchor := Last_Selected;
                        end if;
                     end;
                  end if;

                  Files.Model.Move_Selection (Model, Action.Direction);
                  if Action.Range_Selection then
                     declare
                        New_Index : constant Natural := Files.Model.Selected_Index (Model);
                     begin
                        if Anchor > 0 and then New_Index > 0 then
                           Files.Model.Select_Visible_Range (Model, Positive (Anchor), Positive (New_Index));
                        end if;
                     end;
                  end if;
                  return
                    Make_Result
                      (if Files.Model.Selected_Index (Model) = Old_Index
                         and then Files.Model.Selected_Count (Model) = Old_Count
                       then Controller_Ignored
                       else Controller_Selection_Moved);
               end;
            end if;
         when Files.Events.Scroll_Input_Action =>
            return Handle_Scroll (Model, Action.Scroll_Lines);
         when Files.Events.No_Input_Action
            | Files.Events.Text_Click_Input_Action
            | Files.Events.Settings_Click_Input_Action
            | Files.Events.Item_Click_Input_Action
            | Files.Events.Root_Click_Input_Action
            | Files.Events.Breadcrumb_Click_Input_Action
            | Files.Events.Path_Favorite_Toggle_Input_Action
            | Files.Events.Tree_Click_Input_Action
            | Files.Events.Tree_Pick_Confirm_Input_Action
            | Files.Events.Command_Result_Click_Input_Action
            | Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.Column_Resize_Begin_Input_Action
            | Files.Events.Column_Reorder_Begin_Input_Action
            | Files.Events.Marquee_Begin_Input_Action
            | Files.Events.Permission_Toggle_Input_Action
            | Files.Events.Ownership_Edit_Input_Action
            | Files.Events.Conflict_Click_Input_Action
            | Files.Events.Label_Picker_Choice_Input_Action
            | Files.Events.Search_Scope_Toggle_Input_Action
            | Files.Events.Paste_Cancel_Input_Action =>
            null;
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Key;
