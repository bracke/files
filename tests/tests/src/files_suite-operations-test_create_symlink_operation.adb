separate (Files_Suite.Operations)
   procedure Test_Create_Symlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "symlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Payload   : constant String := "symlink payload contents";
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, Payload);

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
         "create-symlink command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Symlink_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "create-symlink succeeds");
      Assert (Ada.Directories.Exists (Source), "original item still exists after linking");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "a symbolic link is created next to the source");
      Assert
        (Project_Tools.Files.Read_Raw_File (Link_Path) = Project_Tools.Files.Read_Raw_File (Source),
         "the symbolic link resolves to the original contents");
      Assert (Files.Model.Undo_Available (Model), "undo is available after creating a link");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "undo of a created symlink succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created symlink");
      Assert (not Hostkit.Fs.Is_Link (Link_Path), "undo leaves no dangling symlink entry");
      Assert (Ada.Directories.Exists (Source), "undo keeps the original source item");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after undo");
   end Test_Create_Symlink_Operation;
