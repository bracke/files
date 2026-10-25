separate (Files_Suite.Operations)
   procedure Test_Recovery_Mode_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source : constant String := Join (Root, "original");
      Backup : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      procedure Cleanup is
      begin
         Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
      end Cleanup;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "FILES_TEST_DIRECTORY_RESTORE_FAULT");
      Files_Suite.Support.Save (Environment, "FILES_TEST_DIRECTORY_RESTORE_BLOCK");
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Recovery_Mode_Failure", "needs Linux");
         return;
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      for Block_Rollback in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Directory (Source);
         Write_Binary_File (Join (Source, "child"), "original bytes");
         Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "prepare a read-only original");
         Ada.Environment_Variables.Set
           ("FILES_TEST_DIRECTORY_RESTORE_FAULT", Join (Root, ".files-recovery-1/payload"));
         if Block_Rollback then
            Ada.Environment_Variables.Set ("FILES_TEST_DIRECTORY_RESTORE_BLOCK", Source);
         end if;
         Mutation := Files.File_System.Preserve_For_Replace (Source, Backup);
         Assert (not Mutation.Success, "a failed mode restoration reports failure");
         if Block_Rollback then
            Assert (Length (Backup) > 0 and then File_Has_Bytes (Join (To_String (Backup), "child"),
                    "original bytes"), "a refused rollback retains the original in its private backup");
            Assert (File_Has_Bytes (Join (Source, "replacement"), "replacement bytes"),
                    "rollback never overwrites a replacement at the original pathname");
         else
            Files_Suite.Support.Assert_Equal
              (Length (Backup),
               0,
               "a failed restoration rolls back the complete original and its mode: no backup");
            Assert
              (File_Has_Bytes (Join (Source, "child"), "original bytes"),
               "a failed restoration rolls back the complete original and its mode: original bytes restored");
            Assert
              (Metadata_Mode_Of (Source) = 8#555#,
               "a failed restoration rolls back the complete original and its mode: mode restored");
         end if;
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_FAULT");
         Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
         if Block_Rollback then
            Mutation := Files.File_System.Delete_Permanently (Source);
            Assert (Mutation.Success, "remove the test replacement before retrying recovery");
            declare
               Mode_Path : constant String := Join
                 (Ada.Directories.Containing_Directory (To_String (Backup)), "mode");
               Mode_Alias : constant String := Join (Root, "recovery-mode-hardlink");
            begin
               if Hostkit.Fs.Create_Hard_Link (Mode_Path, Mode_Alias) then
                  Mutation := Files.File_System.Restore_From_Trash
                    (To_String (Backup),
                     Files.File_Identities.Token (To_String (Backup)), Source);
                  Assert (not Mutation.Success, "recovery refuses a multiply-linked mode record: refused");
                  Assert
                    (Ada.Directories.Exists (To_String (Backup)),
                     "recovery refuses a multiply-linked mode record: backup kept");
                  Assert
                    (not Ada.Directories.Exists (Source),
                     "recovery refuses a multiply-linked mode record: source not created");
                  Ada.Directories.Delete_File (Mode_Alias);
               else
                  Files_Suite.Support.Link_Not_Made ("Test_Recovery_Mode_Failure", Files_Suite.Support.Hard_Link);
               end if;
            end;
            Mutation := Files.File_System.Restore_From_Trash
              (To_String (Backup), Files.File_Identities.Token (To_String (Backup)), Source);
            Assert (Mutation.Success, "retry restores the original bytes and mode: restored");
            Assert
              (File_Has_Bytes (Join (Source, "child"), "original bytes"),
               "retry restores the original bytes and mode: bytes restored");
            Assert (Metadata_Mode_Of (Source) = 8#555#, "retry restores the original bytes and mode: mode restored");
         end if;
         Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
      end loop;
      for Background in Boolean loop
         declare
            Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
            Model : Files.Model.Window_Model;
            Actions : Files.Paste.Resolved_Action_Vectors.Vector;
            Step : Files.Operations.Operation_Result;
            Copy_Source : constant String := Join (Root, "copy-source");
         begin
            Reset_Root;
            Ada.Directories.Create_Directory (Source);
            Ada.Directories.Create_Directory (Copy_Source);
            Write_Binary_File (Join (Source, "child"), "original bytes");
            Write_Binary_File (Join (Copy_Source, "child"), "replacement copy");
            Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "prepare paste replacement");
            Ada.Environment_Variables.Set
              ("FILES_TEST_DIRECTORY_RESTORE_FAULT", Join (Root, ".files-recovery-1/payload"));
            Ada.Environment_Variables.Set ("FILES_TEST_DIRECTORY_RESTORE_BLOCK", Source);
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Actions.Append (Files.Paste.Resolved_Action'
              (To_Unbounded_String (Copy_Source), To_Unbounded_String (Source), False, True));
            Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
            Step := Complete_Operation
              (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Undo_Available (Model),
                    "failed replacement retains guarded recovery history in foreground and background");
            Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_FAULT");
            Ada.Environment_Variables.Clear ("FILES_TEST_DIRECTORY_RESTORE_BLOCK");
            Assert (Files.File_System.Delete_Permanently (Source).Success, "remove the test rollback obstruction");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo recovers the retained original and mode: status");
            Assert
              (File_Has_Bytes (Join (Source, "child"), "original bytes"),
               "Undo recovers the retained original and mode: bytes restored");
            Assert (Metadata_Mode_Of (Source) = 8#555#, "Undo recovers the retained original and mode: mode restored");
            Mutation := Files.File_System.Set_Permissions (Source, 8#755#);
         exception
            when others =>
               Files.Model.Clear_Paste_Execution (Model);
               Files.Refresh_Jobs.Cancel (Model);
               raise;
         end;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Recovery_Mode_Failure;
