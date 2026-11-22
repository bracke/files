with Files.Operations.History.Testing;
with Files.File_System.Permissions.Testing;
with Files.Model.Jobs;
with Files.Operations.Paste.Testing;
with Files.Operations.History;
with Files.Operations.Paste;
with Files.File_System_Types;
with Files.Operation_Results;
with Files.File_System.Permissions;
with Files.Items;
with Files_Suite.Volumes;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Models;
separate (Files_Suite.Transfer)
   procedure Test_Failed_Replace_Rollback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Tree     : constant String := Join (Root, "replace-source");
      Locked   : constant String := Join (Tree, "locked");
      function Dest return String is (Join (Remote.Path, "replace-target"));
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
      Model    : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operation_Results.Operation_Result;
      Result   : Files.File_System.Mutation_Result;

      procedure Cleanup is
      begin
         Files_Suite.Support.Guards.Release (Paste);
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Root, 8#755#);
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Locked, 8#755#);
      end Cleanup;
   begin
      Reset_Root;
      Remote.Create ("files-test-replace-recovery-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Failed_Replace_Rollback", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Tree), To_Unbounded_String (Dest), False, True));
      for Background in Boolean loop
         Ada.Directories.Create_Path (Locked);
         Write_Binary_File (Join (Locked, "keep"), "complete");
         Write_Binary_File (Dest, "original");
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Locked, 8#555#);
         Assert (Result.Success, "preserve a readonly nested directory in the copied destination");
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Root, 8#555#);
         Assert (Result.Success, "the fixture permits copying but refuses atomic source removal");
         Files.Model.Initialize (Model, Remote.Path, Files.Items.Item_Vectors.Empty_Vector, Root);
         Files.Operations.History.Testing.Clear_Undo (Model);
         Files.Model.Jobs.Set_Background_Transfers (Model, Background);
         Files.Operations.Paste.Testing.Begin_Paste_Execution (Model, Actions, Files.File_System_Types.Drop_Move);
         Step := Files_Suite.Support.Models.Finish_Paste (Model, Settings);
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Root, 8#755#);
         Assert (not Files.Model.Jobs.Foreground_Job_Is_Active (Model)
                 and then Step.Status = Files.Operation_Results.Operation_Failed,
                 "refused source removal completes as a failed replacement");
         Assert (not Files.Model.History.Undo_Available (Model),
                 "rollback restores the original, preserves the source and leaves no unusable history: no history");
         Assert (File_Is (Dest, "original"),
                 "rollback restores the original, preserves the source and leaves no unusable history: original");
         Assert (File_Has_Bytes (Join (Locked, "keep"), "complete"),
                 "rollback restores the original, preserves the source and leaves no unusable history: source");
         Await_View (Model, Settings);
         Result := Files.File_System.Permissions.Testing.Set_Permissions (Locked, 8#755#);
         Project_Tools.Files.Delete_Tree (Tree);
         Ada.Directories.Delete_File (Dest);
      end loop;
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Failed_Replace_Rollback;
