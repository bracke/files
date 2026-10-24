separate (Files_Suite.Operations)
   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Hidden, Visible : Unbounded_String;
      Had_XDG : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Old_XDG : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Had_Backend : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Backend : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      procedure Restore is
      begin
         if Had_XDG then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_XDG);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Backend);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore;
   begin
      for Background in Boolean loop
         for Show_Hidden in Boolean loop
            Reset_Root;
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
            Write_Binary_File (Join (Root, ".hidden"), "hidden bytes");
            Write_Binary_File (Join (Root, "visible"), "visible bytes");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, ".hidden"), Hidden);
            Assert (Mutation.Success, "trash hidden payload");
            Mutation := Files.File_System.Move_To_Trash (Join (Root, "visible"), Visible);
            Assert (Mutation.Success, "trash visible payload");
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Settings.Show_Hidden_Files := Show_Hidden;
            Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not Ada.Directories.Exists (To_String (Hidden))
                    and then not Ada.Directories.Exists (To_String (Visible))
                    and then not Ada.Directories.Exists
                      (Join (Join (Join (Join (Root, "xdg"), "Trash"), "info"), ".hidden.trashinfo")),
                    "Empty Trash purges hidden and visible payloads and hidden restore metadata");
         end loop;
      end loop;
      Restore;
   exception
      when others =>
         Restore; Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Empty_Trash_Hidden;
