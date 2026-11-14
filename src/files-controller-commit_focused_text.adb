with Files.Operation_Results;
separate (Files.Controller)
   function Commit_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result
   is
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation;
   begin
      case Files.Model.Focus (Model) is
         when Files.Types.Focus_Path_Input =>
            Operation := Files.Operations.Commit_Path_Input (Model, Settings);
            return Make_Result (Controller_Command_Executed, Files.Commands.Focus_Path_Input_Command, Operation);
         when Files.Types.Focus_Filter_Input =>
            Files.Model.Cancel_Focus_Or_Edit (Model);
            Operation.Status := Files.Operation_Results.Operation_Success;
            return Make_Result (Controller_Command_Executed, Files.Commands.Focus_Filter_Input_Command, Operation);
         when Files.Types.Focus_Rename_Input =>
            if Files.Model.Temporary_Item_Is_Active (Model) then
               Operation := Files.Operations.Commit_Create_File (Model, Settings);
            else
               Operation := Files.Operations.Commit_Rename (Model, Settings);
            end if;
            return Make_Result (Controller_Command_Executed, Files.Commands.Rename_Selected_Items_Command, Operation);
         when Files.Types.Focus_Command_Palette =>
            return Activate_Palette_Command (Model, Settings, Modifiers);
         when Files.Types.Focus_Settings_Input =>
            declare
               Parsed : constant Files.Settings.Settings_Parse_Result :=
                 Files.Settings.Validate_Draft (Files.Model.Settings_Pane.Draft_Of (Model));
               Draft  : Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
            begin
               if Parsed.Success then
                  Draft.Valid := True;
                  Draft.Error_Key := Null_Unbounded_String;
                  Files.Model.Set_Error (Model, "");
                  Operation.Status := Files.Operation_Results.Operation_Success;
               else
                  Draft.Valid := False;
                  Draft.Error_Key := Parsed.Error_Key;
                  Files.Model.Set_Error (Model, To_String (Parsed.Error_Key));
                  Operation.Status := Files.Operation_Results.Operation_Failed;
                  Operation.Error_Key := Parsed.Error_Key;
               end if;
               Files.Model.Settings_Pane.Set_Draft (Model, Draft);
            end;
            return
              Make_Result
                (Controller_Command_Executed,
                 Files.Commands.Toggle_Settings_Pane_Command,
                 Operation);
         when Files.Types.Focus_Ownership_Input =>
            return Make_Result
              (Controller_Command_Executed, Files.Commands.No_Command,
               Files.Operations.Commit_Ownership_Input (Model, Settings));
         when Files.Types.Focus_None =>
            --  Return over the grid opens the selection.
            return Execute_Non_Settings_Command
              (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end case;
   end Commit_Focused_Text;
