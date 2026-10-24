separate (Files_Suite.Operations)
   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Unbounded_String;
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
      Tree     : constant String := Join (Root, "recovery-tree");
      Locked   : constant String := Join (Tree, "locked");
      Had_Xdg  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg  : constant String :=
        (if Had_Xdg then
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Paths    : Files.Types.String_Vectors.Vector;
      Plans    : Files.File_System.Drop_Import_Result;
      Result   : Files.File_System.Mutation_Result;
      Trashed  : Unbounded_String;

      procedure Unlock (Path : String) is
         Result : constant Files.File_System.Mutation_Result := Files.File_System.Set_Permissions (Path, 8#755#);
         pragma Unreferenced (Result);
      begin
         null;
      end Unlock;

      procedure Cleanup is
      begin
         Files.Job_Context.Initialize ("");
         Unlock (Locked);
         if Length (Trashed) > 0 then
            Unlock (Join (To_String (Trashed), "locked"));
         end if;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
         Restore_Tmp;
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Cleanup;

      procedure Prepare_Tree is
      begin
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Tree, "a.txt"), "complete");
         Write_Binary_File (Join (Locked, "b.txt"), "locked");
      end Prepare_Tree;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Cross_Device_Recovery",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Reset_Root;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-recovery-"));
      Restore_Tmp;
      Assert (Length (Remote) > 0, "create a unique cross-device recovery fixture");
      Write_Binary_File (Join (Root, "mount-probe"), "probe");
      begin
         Ada.Directories.Rename (Join (Root, "mount-probe"), Join (To_String (Remote), "mount-probe"));
         Cleanup;
         return; --  No distinct filesystem available on this host.
      exception
         when Ada.Directories.Use_Error => null;
      end;
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock source deletion but permit copying");
      Paths.Append (To_Unbounded_String (Tree));
      Plans := Files.File_System.Plan_Drop_Import (Paths, To_String (Remote), Files.File_System.Drop_Move);
      Result := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "a copied directory move commits by atomically vacating the source pathname");
      Assert
        (Project_Tools.Files.Read_Raw_File (Join (Join (To_String (Remote), "recovery-tree"), "a.txt")) = "complete"
         and then File_Has_Bytes
           (Join (Join (Join (To_String (Remote), "recovery-tree"), "locked"), "b.txt"), "locked"),
         "refused source cleanup cannot invalidate the complete move destination");
      Unlock (Join (Join (Join (Root, ".files-recovery-1"), "payload"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (Root, ".files-recovery-1"));
      Unlock (Join (Join (To_String (Remote), "recovery-tree"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (To_String (Remote), "recovery-tree"));

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (To_String (Remote), "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock the trash source deletion");
      Result := Files.File_System.Move_To_Trash (Tree, Trashed);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "read-only descendants do not cause partial source deletion during trash (success="
              & Result.Success'Image & ", error=" & To_String (Result.Error_Key)
              & ", source left=" & Ada.Directories.Exists (Tree)'Image & ")");
      Assert
        (Project_Tools.Files.Read_Raw_File (Join (To_String (Trashed), "a.txt")) = "complete",
         "cross-device trash retains its complete payload");
      Assert
        (Ada.Directories.Exists
           (Join (Join (Join (Join (To_String (Remote), "data"), "Trash"), "info"), "recovery-tree.trashinfo")),
         "cross-device trash retains the restore sidecar");
      Unlock (Locked);
      Unlock (Join (To_String (Trashed), "locked"));
      Project_Tools.Files.Delete_Tree (Tree);
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Assert (Result.Success, "cross-device trash remains recoverable");
      Unlock (Locked);
      Project_Tools.Files.Delete_Tree (Tree);

      Prepare_Tree;
      Result := Files.File_System.Move_To_Trash (Tree, Trashed);
      Assert (Result.Success, "prepare a cross-device restore");
      Assert
        (Files.File_System.Set_Permissions (Join (To_String (Trashed), "locked"), 8#000#).Success,
         "make the restore fail after it begins copying");
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Assert (not Result.Success, "a partial restore reports failure");
      Assert (not Ada.Directories.Exists (Tree), "a partial restore never publishes the original path");
      Assert (not Ada.Directories.Exists (Join (Root, ".files-work-1")),
              "failed restore staging is removed through guarded job staging");
      Unlock (Join (To_String (Trashed), "locked"));
      Ada.Directories.Create_Directory (Join (Root, "cancelled-recovery"));
      Write_Binary_File
        (Join (Join (Root, "cancelled-recovery"), "cancel"),
         "cancel" & ASCII.LF);
      Files.Job_Context.Initialize (Join (Root, "cancelled-recovery"));
      Assert (Files.Job_Context.Cancelled, "the restore retry runs after helper cancellation");
      Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
      Files.Job_Context.Initialize ("");
      Assert (Result.Success, "restoring can retry after a partial copy failure and cancellation");
      Assert (Project_Tools.Files.Read_Raw_File (Join (Tree, "a.txt")) = "complete", "retry restores full content");
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Cross_Device_Recovery;
