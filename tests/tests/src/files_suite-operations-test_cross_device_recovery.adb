with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Cross_Device_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Tree     : constant String := Join (Root, "recovery-tree");
      Locked   : constant String := Join (Tree, "locked");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
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
      end Cleanup;

      procedure Prepare_Tree is
      begin
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Tree, "a.txt"), "complete");
         Write_Binary_File (Join (Locked, "b.txt"), "locked");
      end Prepare_Tree;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Cross_Device_Recovery", "needs Linux");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-recovery-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Cross_Device_Recovery", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock source deletion but permit copying");
      Paths.Append (To_Unbounded_String (Tree));
      Plans := Files.File_System.Plan_Drop_Import (Paths, Remote.Path, Files.File_System.Drop_Move);
      Result := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "a copied directory move commits by atomically vacating the source pathname");
      Assert
        (Project_Tools.Files.Read_Raw_File (Join (Join (Remote.Path, "recovery-tree"), "a.txt")) = "complete"
         and then File_Has_Bytes
           (Join (Join (Join (Remote.Path, "recovery-tree"), "locked"), "b.txt"), "locked"),
         "refused source cleanup cannot invalidate the complete move destination");
      Unlock (Join (Join (Join (Root, ".files-recovery-1"), "payload"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (Root, ".files-recovery-1"));
      Unlock (Join (Join (Remote.Path, "recovery-tree"), "locked"));
      Project_Tools.Files.Delete_Tree (Join (Remote.Path, "recovery-tree"));

      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Remote.Path, "data"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Prepare_Tree;
      Assert (Files.File_System.Set_Permissions (Locked, 8#555#).Success, "lock the trash source deletion");
      Result := Files.File_System.Move_To_Trash (Tree, Trashed);
      Assert (Result.Success and then not Ada.Directories.Exists (Tree),
              "read-only descendants do not cause partial source deletion during trash (success="
              & Result.Success'Image & ", error=" & To_String (Result.Error_Key)
              & ", source left=" & Ada.Directories.Exists (Tree)'Image & ")");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (To_String (Trashed), "a.txt")),
         "complete",
         "cross-device trash retains its complete payload");
      Assert
        (Ada.Directories.Exists
           (Join (Join (Join (Join (Remote.Path, "data"), "Trash"), "info"), "recovery-tree.trashinfo")),
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
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Join (Tree, "a.txt")),
         "complete",
         "retry restores full content");
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Cross_Device_Recovery;
