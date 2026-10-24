separate (Files_Suite.Operations)
   procedure Test_Copy_Timestamps (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "destination");
      Remote : Unbounded_String;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
      File_Time, Directory_Time : Ada.Calendar.Time;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
      procedure Prepare is
      begin
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "timestamp bytes");
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Join (Source, "child"), GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Source, GNAT.OS_Lib.GM_Time_Of (2021, 2, 3, 4, 5, 6));
         File_Time := Ada.Directories.Modification_Time (Join (Source, "child"));
         Directory_Time := Ada.Directories.Modification_Time (Source);
      end Prepare;
      procedure Assert_Times (Path : String) is
      begin
         Assert (Ada.Directories.Modification_Time (Path) = Directory_Time
                 and then Ada.Directories.Modification_Time (Join (Path, "child")) = File_Time,
                 "file and directory modification times survive the completed transition");
      end Assert_Times;
   begin
      Reset_Root;
      Prepare;
      Mutation := Files.File_System.Copy_Tree (Source, Dest);
      Assert (Mutation.Success, "copy timestamp fixture");
      Assert_Times (Dest);
      Write_Binary_File (Join (Source, "precise"), "current timestamp with subsecond precision");
      File_Time := Ada.Directories.Modification_Time (Join (Source, "precise"));
      Mutation := Files.File_System.Copy_Tree (Join (Source, "precise"), Join (Root, "precise-copy"));
      Assert (Mutation.Success and then Ada.Directories.Modification_Time (Join (Root, "precise-copy")) = File_Time,
              "timestamp copies preserve the source's subsecond precision");
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Copy_Timestamps",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-timestamps-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Copy_Timestamps", "Length (Remote) = 0");
         return;
      end if;
      Write_Binary_File (Join (Root, "mount-probe"), "probe");
      begin
         Ada.Directories.Rename (Join (Root, "mount-probe"), Join (To_String (Remote), "mount-probe"));
         Cleanup;
         return;
      exception
         when Ada.Directories.Use_Error => null;
      end;
      for Background in Boolean loop
         Reset_Root;
         Prepare;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (To_String (Remote), "source")), False, False));
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Source),
                 "cross-device move publishes a complete destination and removes its source");
         Assert_Times (Join (To_String (Remote), "source"));
         for Cycle in 1 .. 2 loop
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "cross-device Undo refreshes the moved identity");
            Assert_Times (Source);
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "cross-device Redo refreshes the moved identity");
            Assert_Times (Join (To_String (Remote), "source"));
         end loop;
         Project_Tools.Files.Delete_Tree (Join (To_String (Remote), "source"));
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Timestamps;
