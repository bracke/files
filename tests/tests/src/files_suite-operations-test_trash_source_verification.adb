with Files.File_System.Testing;
with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "changing");
      Remote : Files_Suite.Volumes.Remote_Directory;
      --  The start of the trash's private copy of the item.
      function Trigger return String is (Join (Remote.Path, "data/Trash/files/.files-work-"));
      Model : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Paste_Guard (Model'Access);
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      procedure Cleanup is
      begin
         Files_Suite.Support.Release (Paste);
         Files.File_System.Testing.Stop_Changing_Source;
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_TRIGGER");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_SOURCE");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_FAULT");
      end Cleanup;
   begin
      Remote.Create ("files-test-trash-source-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Trash_Source_Verification", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Remote.Path, "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      --  Once the copy into the trash is complete, the source changes: set
      --  here, and in the environment for a background transfer's helper.
      Ada.Environment_Variables.Set ("FILES_TEST_TRASH_TRIGGER", Trigger);
      Ada.Environment_Variables.Set ("FILES_TEST_TRASH_SOURCE", Source);
      for Background in Boolean loop
         for Fault in 1 .. 3 loop
            Reset_Root;
            if Fault = 3 then
               Ada.Directories.Create_Directory (Source);
               Write_Binary_File (Join (Source, "child"), "old bytes");
               Write_Binary_File (Join (Source, "other"), "untouched bytes");
            else
               Write_Binary_File (Source, "old bytes");
            end if;
            Ada.Environment_Variables.Set
              ("FILES_TEST_TRASH_FAULT", (if Fault = 1 then "edit" elsif Fault = 2 then "replace" else "folder"));
            Files.File_System.Testing.Change_Source_After_Copy
              (Trigger, Source,
               (if Fault = 1 then Files.File_System.Testing.Edit_Source
                elsif Fault = 2 then Files.File_System.Testing.Replace_Source
                else Files.File_System.Testing.Edit_Folder_Child));
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Select_All_Visible (Model);
            Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "trash refuses removal when its source changes after copying");
            Assert (File_Has_Bytes ((if Fault = 3 then Join (Source, "child") else Source), "new edits"),
                    "trash retains concurrent source edits or replacements");
            if Fault = 2 then
               Assert (File_Has_Bytes (Source & ".saved", "old bytes"), "the replaced original remains untouched");
            elsif Fault = 3 then
               Assert (File_Has_Bytes (Join (Source, "other"), "untouched bytes"),
                       "refused trash never partially deletes a source tree");
            end if;
            Assert (not Files.Model.Undo_Available (Model), "a rolled-back trash copy records no deletion history");
            Assert (not Ada.Directories.Exists (Join (Remote.Path, "data/Trash/files/changing"))
                    and then not Ada.Directories.Exists
                      (Join (Remote.Path, "data/Trash/info/changing.trashinfo")),
                    "refused source removal rolls back the copied trash payload and sidecar");
         end loop;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Trash_Source_Verification;
