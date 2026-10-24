separate (Files_Suite.Operations)
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Remote   : constant String :=
        "/dev/shm/files_aunit_replace_recovery-" & Ada.Directories.Simple_Name (Root);
      Tree     : constant String := Join (Root, "replace-source");
      Locked   : constant String := Join (Tree, "locked");
      Dest     : constant String := Join (Remote, "replace-target");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String :=
        (if Had_Back then Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Result   : Files.File_System.Mutation_Result;

      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Result := Files.File_System.Set_Permissions (Root, 8#755#);
         Result := Files.File_System.Set_Permissions (Locked, 8#755#);
         Project_Tools.Files.Delete_Tree (Remote);
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Failed_Replace_Rollback",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Reset_Root;
      begin
         Ada.Directories.Create_Directory (Remote);
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error => return;
      end;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Tree), To_Unbounded_String (Dest), False, True));
      for Background in Boolean loop
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Locked, "keep"), "complete");
         Write_Binary_File (Dest, "original");
         Result := Files.File_System.Set_Permissions (Locked, 8#555#);
         Assert (Result.Success, "preserve a readonly nested directory in the copied destination");
         Result := Files.File_System.Set_Permissions (Root, 8#555#);
         Assert (Result.Success, "the fixture permits copying but refuses atomic source removal");
         Files.Model.Initialize (Model, Remote, Files.File_System.Item_Vectors.Empty_Vector, Root);
         Files.Model.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move);
         for Attempt in Files_Suite.Support.Polling loop
            Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            exit when not Files.Model.Paste_Execution_Is_Active (Model);
         end loop;
         Result := Files.File_System.Set_Permissions (Root, 8#755#);
         Assert (not Files.Model.Paste_Execution_Is_Active (Model)
                 and then Step.Status = Files.Operations.Operation_Failed,
                 "refused source removal completes as a failed replacement");
         Assert (not Files.Model.Undo_Available (Model)
                 and then File_Has_Bytes (Dest, "original")
                 and then File_Has_Bytes (Join (Locked, "keep"), "complete"),
                 "rollback restores the original, preserves the source and leaves no unusable history");
         Await_View (Model, Settings);
         Result := Files.File_System.Set_Permissions (Locked, 8#755#);
         Project_Tools.Files.Delete_Tree (Tree);
         Ada.Directories.Delete_File (Dest);
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Failed_Replace_Rollback;
