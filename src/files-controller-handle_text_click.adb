separate (Files.Controller)
   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result
   is
      Old_Focus  : constant Files.Types.Focus_Target := Files.Model.Focus (Model);
      Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
   begin
      if Target = Files.Types.Focus_Command_Palette
        and then not Files.Model.Command_Palette_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Target = Files.Types.Focus_Settings_Input
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Target = Files.Types.Focus_Rename_Input
        and then not Files.Model.Rename_Is_Active (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Root_Selector_Is_Open (Model)
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then Target /= Files.Types.Focus_Settings_Input
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Target is
         when Files.Types.Focus_Path_Input =>
            if Files.Model.Focus (Model) /= Files.Types.Focus_Path_Input then
               Files.Model.Focus_Path_Input (Model);
            end if;
         when Files.Types.Focus_Filter_Input =>
            if Files.Model.Focus (Model) /= Files.Types.Focus_Filter_Input then
               Files.Model.Focus_Filter_Input (Model);
            end if;
         when Files.Types.Focus_Rename_Input =>
            Files.Model.Focus_Rename_Input (Model);
         when Files.Types.Focus_Command_Palette =>
            Files.Model.Focus_Command_Palette_Input (Model);
         when Files.Types.Focus_Settings_Input =>
            --  Settings clicks route through Handle_Settings_Click (the panel
            --  hit-tests them), not the generic text-click path.
            null;
         when Files.Types.Focus_Ownership_Input =>
            --  The ownership editor is opened through its own click action, not
            --  the generic text-click path.
            return Make_Result (Controller_Ignored);
         when Files.Types.Focus_None =>
            return Make_Result (Controller_Ignored);
      end case;

      --  A rename click moves only the clicked field's caret, keeping the
      --  other synchronized carets in place.
      if Target = Files.Types.Focus_Rename_Input then
         Files.Model.Set_Rename_Caret (Model, Item_Index, Cursor_Position);
         return Make_Result (Controller_Text_Updated);
      end if;

      Files.Model.Set_Text_Cursor_Position (Model, Cursor_Position);
      return
        Make_Result
          (if Files.Model.Focus (Model) = Old_Focus
             and then Files.Model.Text_Cursor_Position (Model) = Old_Cursor
           then Controller_Ignored
           else Controller_Text_Updated);
   end Handle_Text_Click;
