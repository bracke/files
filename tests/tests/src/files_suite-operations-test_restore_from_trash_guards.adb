separate (Files_Suite.Operations)
   procedure Test_Restore_From_Trash_Guards (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_restore_guard_xdg";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Backend then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", To_String (Old_Backend));
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      if Had_Xdg_Data then
         Old_Xdg_Data := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_DATA_HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      --  Guard 1: the original path has been re-created since trashing. Restore
      --  must refuse rather than clobber it, and keep the trashed payload. This
      --  behaviour was previously only checked by its catalog string.
      declare
         Source_Path  : constant String := Join (Root, "guard-exists.txt");
         Trashed_Path : constant String := Join (Trash_File, "guard-exists.txt");
      begin
         Write_File (Source_Path, "trashed payload");
         Mutation := Files.File_System.Move_To_Trash (Source_Path);
         Assert (Mutation.Success, "guard setup trashes the file");
         Write_File (Source_Path, "a different file now lives here");
         Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
         Assert (not Mutation.Success, "restore refuses when the original path is occupied");
         Assert
           (To_String (Mutation.Error_Key) = "error.trash.restore_exists",
            "restore-exists refusal reports the localized diagnostic");
         Assert
           (Project_Tools.Files.File_Contains (Source_Path, "a different file now lives here"),
            "restore-exists refusal leaves the occupying file untouched");
         Assert
           (Ada.Directories.Exists (Trashed_Path),
            "restore-exists refusal keeps the trashed payload recoverable");
      end;

      --  Guard 2: the original's parent directory is gone. Restore must refuse
      --  and keep the payload rather than fail obscurely or lose it.
      declare
         Sub_Dir      : constant String := Join (Root, "gone");
         Source_Path  : constant String := Join (Sub_Dir, "guard-parent.txt");
         Trashed_Path : constant String := Join (Trash_File, "guard-parent.txt");
      begin
         Ada.Directories.Create_Path (Sub_Dir);
         Write_File (Source_Path, "payload");
         Mutation := Files.File_System.Move_To_Trash (Source_Path);
         Assert (Mutation.Success, "parent-guard setup trashes the file");
         Project_Tools.Files.Delete_Tree (Sub_Dir);
         Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
         Assert (not Mutation.Success, "restore refuses when the original parent is gone");
         Assert
           (To_String (Mutation.Error_Key) = "error.trash.restore_parent_missing",
            "restore-parent-missing refusal reports the localized diagnostic");
         Assert
           (Ada.Directories.Exists (Trashed_Path),
            "restore-parent-missing refusal keeps the trashed payload recoverable");
      end;

      --  Metadata from other freedesktop trash implementations is external
      --  input. Refuse an oversized sidecar before Get_Line can allocate it.
      declare
         Trashed_Path : constant String := Join (Trash_File, "oversized.txt");
         Sidecar      : constant String := Join (Trash_Info, "oversized.txt.trashinfo");
         File         : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Sidecar);
         Ada.Streams.Stream_IO.Set_Index
           (File, Ada.Streams.Stream_IO.Count (1024 * 1024 + 1));
         Character'Write (Ada.Streams.Stream_IO.Stream (File), 'x');
         Ada.Streams.Stream_IO.Close (File);
         Assert
           (Files.File_System.Trash_Original_Path (Trashed_Path) = "",
            "oversized trash metadata is rejected before parsing");
      end;

      declare
         Trashed_Path : constant String := Join (Trash_File, "relative-path.txt");
         Sidecar      : constant String := Join (Trash_Info, "relative-path.txt.trashinfo");
      begin
         Write_File (Trashed_Path, "payload");
         Write_File
           (Sidecar,
            "[Trash Info]" & ASCII.LF
            & "Path=relative-restore-target.txt" & ASCII.LF);
         Assert
           (Files.File_System.Trash_Original_Path (Trashed_Path) = "",
            "trash metadata refuses a relative original path");
         Mutation := Files.File_System.Restore_From_Trash (Trashed_Path);
         Assert
           (not Mutation.Success and then Ada.Directories.Exists (Trashed_Path),
            "a relative original path cannot move a trash payload into the process directory");
      end;

      declare
         Trashed_Path : constant String := Join (Trash_File, "nul-path.txt");
         Sidecar      : constant String := Join (Trash_Info, "nul-path.txt.trashinfo");
      begin
         Write_File (Trashed_Path, "payload");
         Write_File
           (Sidecar,
            "[Trash Info]" & ASCII.LF
            & "Path=/tmp/files-invalid%00path" & ASCII.LF);
         Assert
           (Files.File_System.Trash_Original_Path (Trashed_Path) = "",
            "trash metadata refuses a decoded NUL in the original path");
      end;

      declare
         Outside : constant String := Join (Root, "outside-trash.txt");
         Target  : constant String := Join (Root, "outside-restore-target.txt");
      begin
         Write_File (Outside, "unrelated payload");
         Mutation := Files.File_System.Restore_From_Trash
           (Outside, Expected_Original => Target);
         Assert
           (not Mutation.Success
            and then Project_Tools.Files.File_Contains (Outside, "unrelated payload")
            and then not Ada.Directories.Exists (Target),
            "restore refuses an entry outside the active trash payload directory");
         Mutation := Files.File_System.Delete_Trashed_Item (Outside);
         Assert
           (not Mutation.Success
            and then Project_Tools.Files.File_Contains (Outside, "unrelated payload"),
            "trash deletion refuses an entry outside the active payload directory");
      end;

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash_Guards;
