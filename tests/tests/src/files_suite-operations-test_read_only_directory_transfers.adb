separate (Files_Suite.Operations)
   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
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
      procedure Remove (Path : String) is
         Result : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Created_Entry
           (Path, Files.File_Identities.Token (Path), Files.File_System.Tree_Revision (Path));
      begin
         Assert (Result.Success, "clean up the owned read-only tree");
      end Remove;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Ada.Directories.Exists (Source) then
            Remove (Source);
         end if;
         if Ada.Directories.Exists (Join (Root, "copy")) then
            Remove (Join (Root, "copy"));
         end if;
         if Length (Remote) > 0 then
            Remove (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String) is
      begin
         Assert (Metadata_Mode_Of (Path) = 8#555# and then Metadata_Mode_Of (Join (Path, "locked")) = 8#555#
                 and then Metadata_Mode_Of (Join (Path, "locked/child")) = 8#444#
                 and then File_Has_Bytes (Join (Path, "locked/child"), "read-only bytes"),
                 "publication and history preserve root, child directory and file permissions");
      end Check;
      procedure Check_Backups (Parent : String) is
         Listing : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Parent, Settings);
      begin
         for Item of Listing.Items loop
            declare
               Name : constant String := To_String (Item.Name);
            begin
               Assert (Name'Length < 16 or else Name (Name'First .. Name'First + 15) /= ".files-recovery-",
                       "committed moves remove their private read-only source backups");
            end;
         end loop;
      end Check_Backups;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Read_Only_Directory_Transfers",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-read-only-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Read_Only_Directory_Transfers", "Length (Remote) = 0");
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Source, "locked"));
         Write_Binary_File (Join (Source, "locked/child"), "read-only bytes");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked/child"), 8#444#).Success,
                 "protect the source file");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked"), 8#555#).Success,
                 "protect the child source directory");
         Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "protect the source root");
         Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
         Assert (Mutation.Success, "publish a copy of a read-only directory");
         Check (Source);
         Check (Join (Root, "copy"));
         Remove (Join (Root, "copy"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To
              (Model, Settings, Paths, To_String (Remote), Files.File_System.Drop_Move));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Source),
                 "move a read-only root across filesystems");
         for Cycle in 1 .. 2 loop
            Check (Join (To_String (Remote), "source"));
            Check_Backups (Root);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Undo a read-only directory move");
            Check (Source);
            Check_Backups (To_String (Remote));
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo a read-only directory move");
         end loop;
         Remove (Join (To_String (Remote), "source"));
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Read_Only_Directory_Transfers;
