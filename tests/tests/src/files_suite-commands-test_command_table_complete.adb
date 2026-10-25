separate (Files_Suite.Commands)
   procedure Test_Command_Table_Complete (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Executed : Natural := 0;
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Identifier (Files.Commands.No_Command), "", "the no-command has no identifier");
      Files_Suite.Support.Assert_Equal
        (Files.Commands.Name_Key (Files.Commands.No_Command), "", "the no-command has no name key");
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Name : constant String := Files.Commands.Command_Id'Image (Id);
            Text : constant String := Files.Commands.Identifier (Id);
         begin
            Assert (Text /= "", "every registered command has an identifier: " & Name);
            Assert (Files.Commands.Name_Key (Id) /= "", "every registered command has a name key: " & Name);
            Files_Suite.Support.Assert_Equal
              (Files.Commands.Id_For_Identifier (Text), Id, "the identifier finds its own command: " & Name);
            for Other in Files.Commands.Registered_Command_Id loop
               if Files.Commands.Command_Id'Pos (Other) /= Files.Commands.Command_Id'Pos (Id) then
                  Assert
                    (Files.Commands.Identifier (Other) /= Text,
                     "command identifiers are unique: " & Name & " and " & Files.Commands.Command_Id'Image (Other));
               end if;
            end loop;
         end;
      end loop;

      --  Every pure command that is enabled runs through the one dispatch path
      --  without raising. A selection makes the selection commands enabled.
      for Id in Files.Commands.Pure_Command_Id loop
         declare
            Model  : Files.Model.Window_Model := Sample_Model;
            Result : Files.Controller.Controller_Result;
         begin
            Files.Model.Move_Selection (Model, Guikit.Input.Move_Right);
            if Files.Commands.Is_Enabled (Id, Model) then
               Result := Files.Controller.Execute_Command (Id, Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Result.Status,
                  Files.Controller.Controller_Command_Executed,
                  "an enabled pure command executes: " & Files.Commands.Command_Id'Image (Id));
               Executed := Executed + 1;
            end if;
         end;
      end loop;
      Assert (Executed >= 15, "most pure commands are enabled with a selection, so the loop is not vacuous");

      --  One table maps each sort field to its command; both directions and the
      --  label key read it.
      for Field in Files.Types.Sort_Field loop
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Sort_Field_For (Files.Commands.Sort_Command (Field)),
            Field,
            "a sort field's command sorts by that field");
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Sort_Label_Key (Field),
            Files.Commands.Name_Key (Files.Commands.Sort_Command (Field)),
            "a sort field's label is its command's name");
      end loop;
      for Id in Files.Commands.Sort_Command_Id loop
         Files_Suite.Support.Assert_Equal
           (Files.Commands.Sort_Command (Files.Commands.Sort_Field_For (Id)),
            Id,
            "a sort command is the command of the field it sorts by");
      end loop;
   end Test_Command_Table_Complete;
