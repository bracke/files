separate (Files_Suite.Operations)
   procedure Test_Native_Replace_Recovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "native-source");
      Dest     : constant String := Join (Root, "native-dest");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Had_Test_Temp : constant Boolean :=
        Ada.Environment_Variables.Exists ("FILES_TEST_TEMP");
      Old_Test_Temp : constant String :=
        Ada.Environment_Variables.Value ("FILES_TEST_TEMP", "");
      Model    : Files.Model.Window_Model;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Backup   : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Paths    : Files.Types.String_Vectors.Vector;
      Relative_Target : constant String := "files-recovery-relative-target.txt";
      Relative_Registry : constant String :=
        "files-relative-recovery-" & Ada.Directories.Simple_Name (Root);
      Registry_Source : constant String := Join (Root, "registry-source");

      procedure Restore_Test_Temp is
      begin
         if Had_Test_Temp then
            Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Old_Test_Temp);
         else
            Ada.Environment_Variables.Clear ("FILES_TEST_TEMP");
         end if;
      end Restore_Test_Temp;

      procedure Restore_Environment is
      begin
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
         Restore_Test_Temp;
      end Restore_Environment;
   begin
      Reset_Root;
      declare
         Fake_Stage : constant String := Join (Root, ".files-recovery-900");
         Fake_Payload : constant String := Join (Fake_Stage, "payload");
      begin
         Ada.Directories.Create_Directory (Fake_Stage);
         Write_Binary_File (Fake_Payload, "unowned");
         Write_Binary_File (Join (Fake_Stage, "original"), Dest);
         Assert
           (not Files.File_System.Is_Recovery_Payload (Fake_Payload),
            "a matching filename without an ownership record is not recovery data");
         Assert
           (Ada.Directories.Exists (Fake_Payload),
            "the recovery gate leaves recovery-shaped user data alone");
         Project_Tools.Files.Delete_Tree (Fake_Stage);
      end;
      Write_Binary_File (Registry_Source, "registry payload");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Ada.Environment_Variables.Set ("FILES_TEST_TEMP", Relative_Registry);
      Result := Files.File_System.Preserve_For_Replace (Registry_Source, Backup);
      Restore_Test_Temp;
      Assert
        (not Result.Success
         and then Length (Backup) = 0
         and then Project_Tools.Files.File_Contains
           (Registry_Source, "registry payload")
         and then not Ada.Directories.Exists (Relative_Registry),
         "a relative recovery registry root cannot redirect private records into the process directory");
      Ada.Directories.Delete_File (Registry_Source);
      Write_Binary_File (Source, "new");
      Write_Binary_File (Dest, "original");
      Actions.Append (Files.Paste.Resolved_Action'
                        (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, True));
      for Backend of Files.Types.String_Vectors.Vector'([To_Unbounded_String ("windows"),
                                                       To_Unbounded_String ("macos")]) loop
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Backend));
         for Background in Boolean loop
            Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
            for Attempt in 1 .. 5_000 loop
               Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               exit when not Files.Model.Paste_Execution_Is_Active (Model);
               delay 0.001;
            end loop;
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "Replace succeeds with a restorable native-backend backup");
            Assert (Project_Tools.Files.Read_Raw_File (Dest) = "new", "Replace publishes the new copy");
            Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            --  Failed once on CI (2026-10-22) with no publish error beside it:
            --  name the status and key, so the next failure says which.
            Assert (Step.Status = Files.Operations.Operation_Success,
                    "native-backend Replace is undoable (" & To_String (Backend)
                    & (if Background then ", background" else ", foreground") & "): "
                    & Files.Operations.Operation_Status'Image (Step.Status) & " " & To_String (Step.Error_Key));
            Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "Undo restores the overwritten original");
            Assert (not Files.Model.Redo_Available (Model), "Replace with a backup remains undo-only");
         end loop;
      end loop;
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "the rollback failure fixture preserves the original");
      declare
         Owner_Path : constant String :=
           Join
             (Ada.Directories.Containing_Directory (To_String (Backup)),
              ".files-recovery-owner");
         Owner_Alias : constant String := Join (Root, "recovery-owner-hardlink");
         Owner_Data : constant String :=
           Project_Tools.Files.Read_Raw_File (Owner_Path);
      begin
         if Hostkit.Fs.Create_Hard_Link (Owner_Path, Owner_Alias) then
            Assert
              (not Files.File_System.Is_Recovery_Payload (To_String (Backup)),
               "recovery rejects a multiply-linked ownership record");
            Ada.Directories.Delete_File (Owner_Alias);
         end if;
         Write_Binary_File (Owner_Path, Owner_Data & "trailing");
         Assert
           (not Files.File_System.Is_Recovery_Payload (To_String (Backup)),
            "recovery ownership records reject trailing data");
         Write_Binary_File (Owner_Path, Owner_Data);
         Assert
           (Files.File_System.Is_Recovery_Payload (To_String (Backup)),
            "restoring the exact ownership record restores recognition");
      end;
      declare
         Registered : constant Files.Types.String_Vectors.Vector :=
           Files.File_System.Registered_Recovery_Payloads;
         Found : Boolean := False;
         Intruder : constant String := Join
           (Ada.Directories.Containing_Directory (To_String (Backup)), "unrelated");
      begin
         for Payload of Registered loop
            Found := Found or else Payload = Backup;
         end loop;
         Assert (Found, "native recovery is discoverable without knowing its parent directory");
         Ada.Directories.Delete_File
           (Join (Ada.Directories.Containing_Directory (To_String (Backup)), "original"));
         Assert
           (Files.File_System.Trash_Original_Path (To_String (Backup)) = Dest,
            "the ownership record retains the original path when the legacy sidecar is lost");
         Write_Binary_File (Intruder, "must survive");
         Result := Files.File_System.Delete_Trashed_Item (To_String (Backup));
         Assert
           (not Result.Success and then Ada.Directories.Exists (Intruder),
            "discard refuses a recovery directory containing unknown data");
         Ada.Directories.Delete_File (Intruder);
      end;
      Result := Files.File_System.Restore_From_Trash
        (To_String (Backup), Expected_Original => Relative_Target);
      Assert
        (not Result.Success
         and then Ada.Directories.Exists (To_String (Backup))
         and then not Ada.Directories.Exists (Relative_Target),
         "recovery refuses a relative caller-supplied restore path");
      Result := Files.File_System.Restore_From_Trash
        (To_String (Backup),
         Expected_Original => Dest & Character'Val (0) & "suffix");
      Assert
        (not Result.Success and then Ada.Directories.Exists (To_String (Backup)),
         "recovery refuses a caller-supplied restore path containing NUL");
      Write_Binary_File (Dest, "unrelated");
      Result := Files.File_System.Restore_From_Trash (To_String (Backup));
      Assert (not Result.Success and then Ada.Directories.Exists (To_String (Backup)),
              "a failed rollback preserves its backup for retry");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "unrelated", "rollback never overwrites a collision");
      Paths.Append (Backup);
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Paths, Files.Types.String_Vectors.Empty_Vector, Redoable => False);
      Ada.Directories.Delete_File (Dest);
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Step.Status = Files.Operations.Operation_Success, "recovery Undo can retry after a rollback collision");
      Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "recovery retry restores the original bytes");
      Restore_Environment;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Restore_Environment; raise;
   end Test_Native_Replace_Recovery;
