separate (Files_Suite.Operations)
   procedure Test_Transport_Cleanup_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;

      --  The cleanup entry point must fail closed even when an arbitrary
      --  directory's current identity is supplied by its caller.
      declare
         Victim : constant String := Join (Root, "cleanup-victim");
      begin
         Ada.Directories.Create_Directory (Victim);
         Write_Binary_File (Join (Victim, "keep"), "unrelated");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (Victim, Files.File_Identities.Token (Victim), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0),
            "cleanup refuses an arbitrary unmarked directory: refused");
         Assert (Ada.Directories.Exists (Victim), "cleanup refuses an arbitrary unmarked directory: directory kept");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Join (Victim, "keep")),
            "unrelated",
            "cleanup refuses an arbitrary unmarked directory: contents untouched");
      end;

      declare
         Job        : Files.Process_Jobs.Session;
         Directory  : Files.Types.UString;
         Marker     : Files.Types.UString;
         Original   : Files.Types.UString;
         Recorded   : Files.Types.UString;
         Read_Error : Boolean;
         Rejected   : Boolean;
      begin
         Files.Process_Jobs.Reserve (Job);
         Directory := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Marker := To_Unbounded_String
           (Join (To_String (Directory), ".files-job-transport"));
         Original := To_Unbounded_String
           (Project_Tools.Files.Read_Raw_File (To_String (Marker)));
         Write_Binary_File (To_String (Marker), To_String (Original) & "trailing");
         Files.Job_Transports.Inspect_Marker
           (To_String (Directory), Recorded, Read_Error);
         Rejected := Length (Recorded) = 0 and then not Read_Error;
         Write_Binary_File (To_String (Marker), To_String (Original));
         Files.Process_Jobs.Reset (Job);
         Assert
           (Rejected,
            "transport ownership markers reject trailing data as invalid");
      end;

      declare
         Link_Path : constant String := Join (Root, "dangling-transport-link");
         Linked : constant Boolean := Hostkit.Fs.Create_Link
           (Join (Root, "missing-link-target"), Link_Path);
      begin
         if Linked then
            Assert
              (Hostkit.Fs.Is_Link (Link_Path),
               "cleanup never reports a dangling symlink as a removed transport: link present");
            Assert
              (not Files.Job_Helpers.Run_Cleanup
                 (Link_Path, "untrusted", Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0),
               "cleanup never reports a dangling symlink as a removed transport: not reported removed");
            Assert
              (Hostkit.Fs.Is_Link (Link_Path),
               "cleanup never reports a dangling symlink as a removed transport: link kept");
            Ada.Directories.Delete_File (Link_Path);
         else
            Files_Suite.Support.Link_Not_Made ("Test_Transport_Cleanup_Guards", Files_Suite.Support.Symbolic_Link);
         end if;
      end;

      --  A marked transport is removed through the symlink-safe owned-tree
      --  path, so injected links cannot redirect recursive cleanup.
      declare
         Job       : Files.Process_Jobs.Session;
         Owned     : Files.Types.UString;
         Target    : constant String := Join (Root, "cleanup-link-target");
         Link_Path : Files.Types.UString;
         Linked    : Boolean;
      begin
         Ada.Directories.Create_Directory (Target);
         Write_Binary_File (Join (Target, "keep"), "target");
         Files.Process_Jobs.Reserve (Job);
         Owned := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Link_Path := To_Unbounded_String (Join (To_String (Owned), "injected-link"));
         Linked := Hostkit.Fs.Create_Link (Target, To_String (Link_Path));
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then Ada.Directories.Exists (To_String (Owned)),
            "cleanup refuses a marked transport while its owner holds the lease");
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Assert
           (Files.Job_Helpers.Run_Cleanup
              (To_String (Owned), Files.File_Identities.Token (To_String (Owned)),
               Attempt_Limit => 1, Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0)
            and then not Ada.Directories.Exists (To_String (Owned)),
            "cleanup removes an abandoned marked transport under its own claim");
         Assert
           (not Linked or else Project_Tools.Files.Read_Raw_File (Join (Target, "keep")) = "target",
            "transport cleanup unlinks an injected symlink without following it");
      end;

      --  A marker copied from the genuine directory does not authorize a
      --  replacement subsequently installed at the same pathname.
      declare
         Job      : Files.Process_Jobs.Session;
         Original : Files.Types.UString;
         Saved    : Files.Types.UString;
         Expected : Files.Types.UString;
         Marker   : constant String := ".files-job-transport";

         procedure Restore is
         begin
            --  Windows refuses to remove the transport while its lease handle
            --  is open, so release the session before restoring the fixture.
            Files.Process_Jobs.Reset (Job);
            if Length (Original) > 0 and then Ada.Directories.Exists (To_String (Original)) then
               Project_Tools.Files.Delete_Tree (To_String (Original));
            end if;
            if Length (Saved) > 0 and then Ada.Directories.Exists (To_String (Saved)) then
               Ada.Directories.Rename (To_String (Saved), To_String (Original));
            end if;
         end Restore;
      begin
         Files.Process_Jobs.Reserve (Job);
         Original := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Saved := Original & "-saved";
         Expected := To_Unbounded_String (Files.File_Identities.Token (To_String (Original)));
         Files.Process_Jobs.Testing.Release_Owner (Job);
         Ada.Directories.Rename (To_String (Original), To_String (Saved));
         Ada.Directories.Create_Directory (To_String (Original));
         Write_Binary_File
           (Join (To_String (Original), Marker),
            Project_Tools.Files.Read_Raw_File (Join (To_String (Saved), Marker)));
         Write_Binary_File (Join (To_String (Original), "keep"), "replacement");
         Assert
           (not Files.Job_Helpers.Run_Cleanup
              (To_String (Original), To_String (Expected), Attempt_Limit => 1,
               Initial_Retry_Delay => 0.0, Maximum_Retry_Delay => 0.0),
            "cleanup refuses a replacement carrying the original transport marker: refused");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Join (To_String (Original), "keep")),
            "replacement",
            "cleanup refuses a replacement carrying the original transport marker: replacement contents kept");
         Assert
           (Ada.Directories.Exists (To_String (Saved)),
            "cleanup refuses a replacement carrying the original transport marker: saved original kept");
         Restore;
      exception
         when others => Restore; raise;
      end;
   end Test_Transport_Cleanup_Guards;
