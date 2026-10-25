separate (Files.Commands)
   procedure Execute
     (Id    : Pure_Command_Id;
      Model : in out Files.Model.Window_Model)
   is
   begin
      case Id is
         when No_Command =>
            null;
         when Select_Small_Icons_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
         when Select_Large_Icons_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
         when Select_Details_Command =>
            Files.Model.Set_View_Mode (Model, Files.Types.Details);
         when Toggle_Info_Pane_Command =>
            Files.Model.Toggle_Info_Pane (Model);
         when Toggle_Sort_Menu_Command =>
            Files.Model.Toggle_Sort_Menu (Model);
         when Sort_Command_Id =>
            Files.Model.Select_Sort_Field (Model, Sort_Field_For (Id));
         when Focus_Path_Input_Command =>
            Files.Model.Focus_Path_Input (Model);
            Files.Model.Set_Error (Model, "");
         when Rename_Selected_Items_Command =>
            Files.Model.Toggle_Rename (Model);
         when Focus_Filter_Input_Command =>
            Files.Model.Focus_Filter_Input (Model);
            Files.Model.Set_Error (Model, "");
         when Open_Command_Palette_Command =>
            Files.Model.Toggle_Command_Palette (Model);
            Files.Model.Set_Error (Model, "");
         when Clear_Filter_Command =>
            Files.Model.Clear_Filter (Model);
         when Select_All_Command =>
            Files.Model.Select_All_Visible (Model);
         when Invert_Selection_Command =>
            Files.Model.Invert_Selection (Model);
         when Deselect_All_Command =>
            Files.Model.Deselect_All (Model);
         when Copy_Path_Command =>
            --  Building the newline-joined selection paths is pure; the shell
            --  reads the recorded request and writes the system clipboard.
            Files.Model.Set_System_Clipboard_Request
              (Model, Joined_Full_Paths (Files.Model.Selected_Items (Model)));
            Files.Model.Set_Error (Model, "");
         when Set_Color_Label_Command =>
            --  Opening the swatch picker is pure model state; the chosen label is
            --  applied and persisted through the settings-write seam when the
            --  user clicks a swatch.
            Files.Model.Open_Label_Picker (Model);
            Files.Model.Set_Error (Model, "");
      end case;
   end Execute;
