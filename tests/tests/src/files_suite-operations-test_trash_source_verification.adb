separate (Files_Suite.Operations)
   procedure Test_Trash_Source_Verification (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "changing");
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      procedure Reset_Fault with Import, Convention => C, External_Name => "files_test_fault_reset";
      type Saved_Environment is record
         Name : Unbounded_String;
         Present : Boolean;
         Value : Unbounded_String;
      end record;
      function Save (Name : String) return Saved_Environment is
        ((To_Unbounded_String (Name), Ada.Environment_Variables.Exists (Name),
          To_Unbounded_String (Ada.Environment_Variables.Value (Name, ""))));
      Saved : constant array (Positive range <>) of Saved_Environment :=
        [Save ("TMPDIR"), Save ("XDG_DATA_HOME"), Save ("FILES_TRASH_BACKEND")];
      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_TRIGGER");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_SOURCE");
         Ada.Environment_Variables.Clear ("FILES_TEST_TRASH_FAULT");
         for Item of Saved loop
            if Item.Present then
               Ada.Environment_Variables.Set (To_String (Item.Name), To_String (Item.Value));
            else
               Ada.Environment_Variables.Clear (To_String (Item.Name));
            end if;
         end loop;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Trash_Source_Verification",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-trash-source-"));
      if Saved (1).Present then
         Ada.Environment_Variables.Set ("TMPDIR", To_String (Saved (1).Value));
      else
         Ada.Environment_Variables.Clear ("TMPDIR");
      end if;
      Assert (Length (Remote) > 0, "create an isolated cross-filesystem trash fixture");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (To_String (Remote), "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set
        ("FILES_TEST_TRASH_TRIGGER", Join (To_String (Remote), "data/Trash/files/.files-work-"));
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
            Reset_Fault;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
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
            Assert (not Ada.Directories.Exists (Join (To_String (Remote), "data/Trash/files/changing"))
                    and then not Ada.Directories.Exists
                      (Join (To_String (Remote), "data/Trash/info/changing.trashinfo")),
                    "refused source removal rolls back the copied trash payload and sidecar");
         end loop;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Trash_Source_Verification;
