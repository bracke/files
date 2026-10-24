separate (Files_Suite.Operations)
   procedure Test_Restore_From_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Trash_Home   : constant String := Root & "_restore_xdg_data";
      Trash_File   : constant String := Join (Join (Trash_Home, "Trash"), "files");
      Trash_Info   : constant String := Join (Join (Trash_Home, "Trash"), "info");
      Source_Path  : constant String := Join (Root, "restore-me.txt");
      Had_Xdg_Data : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Home     : constant Boolean := Ada.Environment_Variables.Exists ("HOME");
      Had_Backend  : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg_Data : Unbounded_String;
      Old_Home     : Unbounded_String;
      Old_Backend  : Unbounded_String;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Result       : Files.Controller.Controller_Result;
      Mutation     : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg_Data then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", To_String (Old_Xdg_Data));
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;

         if Had_Home then
            Ada.Environment_Variables.Set ("HOME", To_String (Old_Home));
         else
            Ada.Environment_Variables.Clear ("HOME");
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
      if Had_Home then
         Old_Home := To_Unbounded_String (Ada.Environment_Variables.Value ("HOME"));
      end if;
      if Had_Backend then
         Old_Backend := To_Unbounded_String (Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND"));
      end if;

      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

      Write_File (Source_Path, "payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "restore setup moves source file to trash");
      Assert (not Ada.Directories.Exists (Source_Path), "restore setup removes source file");
      Assert (Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")), "restore setup stores trashed payload");
      Assert
        (Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore setup writes trashinfo sidecar");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Assert (Load.Success, "restore navigates into trash files directory");
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Assert (Files.Model.Current_Is_Trash (Model), "entering the trash settles that it is the trash");
      Assert
        (not Files.Model.Current_Is_Trash (Files_Suite.Support.Sample_Model),
         "an ordinary directory is not the trash");
      Select_Name (Model, "restore-me.txt");
      Assert (Files.Model.Selected_Count (Model) = 1, "restore selects the trashed item");

      Result :=
        Files.Controller.Execute_Command (Files.Commands.Restore_From_Trash_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "restore command returns success");
      Assert (Ada.Directories.Exists (Source_Path), "restore returns the file to its original path");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "restore-me.txt")),
         "restore removes the trashed payload");
      Assert
        (not Ada.Directories.Exists (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "restore removes the trashinfo sidecar");

      Write_File (Source_Path, "permanent payload");
      Mutation := Files.File_System.Move_To_Trash (Source_Path);
      Assert (Mutation.Success, "permanent-delete setup moves source file to trash");
      Assert
        (Ada.Directories.Exists (Join (Trash_File, "restore-me.txt"))
         and then Ada.Directories.Exists
           (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "permanent-delete setup creates a payload and sidecar");
      Load := Files.File_System.Load_Directory
        (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Initialize (Model, To_String (Load.Path), Load.Items, Root);
      Select_Name (Model, "restore-me.txt");
      Result :=
        Files.Controller.Execute_Command
          (Files.Commands.Delete_Selected_Permanently_Command, Model, Settings);
      Assert
        (Result.Operation.Status = Files.Operations.Operation_Success,
         "permanent delete succeeds for a selected trash entry");
      Assert
        (not Ada.Directories.Exists (Join (Trash_File, "restore-me.txt"))
         and then not Ada.Directories.Exists
           (Join (Trash_Info, "restore-me.txt.trashinfo")),
         "permanent delete removes both the trash payload and its sidecar");

      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Restore_From_Trash;
