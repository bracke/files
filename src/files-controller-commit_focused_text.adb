separate (Files.Controller)
   function Commit_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result
   is
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      case Files.Model.Focus (Model) is
         when Files.Types.Focus_Path_Input =>
            Operation := Files.Operations.Commit_Path_Input (Model, Settings);
            return Make_Result (Controller_Command_Executed, Files.Commands.Focus_Path_Input_Command, Operation);
         when Files.Types.Focus_Filter_Input =>
            Files.Model.Cancel_Focus_Or_Edit (Model);
            Operation.Status := Files.Operations.Operation_Success;
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
                 Files.Settings.Validate_Draft (Files.Model.Settings_Draft_Of (Model));
               Draft  : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
            begin
               if Parsed.Success then
                  Draft.Valid := True;
                  Draft.Error_Key := Null_Unbounded_String;
                  Files.Model.Set_Error (Model, "");
                  Operation.Status := Files.Operations.Operation_Success;
               else
                  Draft.Valid := False;
                  Draft.Error_Key := Parsed.Error_Key;
                  Files.Model.Set_Error (Model, To_String (Parsed.Error_Key));
                  Operation.Status := Files.Operations.Operation_Failed;
                  Operation.Error_Key := Parsed.Error_Key;
               end if;
               Files.Model.Set_Settings_Draft (Model, Draft);
            end;
            return
              Make_Result
                (Controller_Command_Executed,
                 Files.Commands.Toggle_Settings_Pane_Command,
                 Operation);
         when Files.Types.Focus_Ownership_Input =>
            declare
               Raw   : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Model.Ownership_Input_Text (Model), Ada.Strings.Both);
               Group : constant Boolean := Files.Model.Ownership_Editing_Group (Model);
               Item  : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
               Resolved : Natural := 0;
               Found    : Boolean := False;

               function Is_Numeric (Text : String) return Boolean is
               begin
                  if Text'Length = 0 then
                     return False;
                  end if;
                  for Ch of Text loop
                     if Ch not in '0' .. '9' then
                        return False;
                     end if;
                  end loop;
                  return True;
               end Is_Numeric;
            begin
               if Is_Numeric (Raw) then
                  begin
                     Resolved := Natural'Value (Raw);
                     Found := True;
                  exception
                     when others =>
                        Found := False;
                  end;
               elsif Group then
                  Resolved := Files.File_System.Group_Id_For_Name (Raw, Found);
               else
                  Resolved := Files.File_System.User_Id_For_Name (Raw, Found);
               end if;

               if not Found then
                  Files.Model.Set_Error (Model, "error.ownership.invalid_name");
                  Files.Model.Cancel_Focus_Or_Edit (Model);
                  Operation.Status := Files.Operations.Operation_Failed;
                  Operation.Error_Key := To_Unbounded_String ("error.ownership.invalid_name");
                  return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
               end if;

               if Group then
                  Operation :=
                    Files.Operations.Set_Ownership_For (Model, Item.Owner_Id, Resolved, Settings);
               else
                  Operation :=
                    Files.Operations.Set_Ownership_For (Model, Resolved, Item.Group_Id, Settings);
               end if;
               Files.Model.Cancel_Focus_Or_Edit (Model);
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
            end;
         when others =>
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end case;
   end Commit_Focused_Text;
