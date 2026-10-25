separate (Files_Suite.Operations)
   procedure Test_Empty_Trash_Hidden (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Hidden, Visible : Unbounded_String;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
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
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Empty Trash purges hidden and visible payloads and hidden restore metadata: status");
            Assert (not Ada.Directories.Exists (To_String (Hidden)),
                    "Empty Trash purges hidden and visible payloads and hidden restore metadata: hidden payload");
            Assert (not Ada.Directories.Exists (To_String (Visible)),
                    "Empty Trash purges hidden and visible payloads and hidden restore metadata: visible payload");
            Assert (not Ada.Directories.Exists
                      (Join (Join (Join (Join (Root, "xdg"), "Trash"), "info"), ".hidden.trashinfo")),
                    "Empty Trash purges hidden and visible payloads and hidden restore metadata: hidden metadata");
         end loop;
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Empty_Trash_Hidden;
