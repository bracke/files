separate (Files_Suite.Operations)
   procedure Test_Create_Hardlink_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "hardlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Payload   : constant String := "hard link payload contents";
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
        (Files.Commands.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
         "create-hard-link command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "create-hard-link succeeds");
      Assert (Ada.Directories.Exists (Source), "original file still exists after linking");
      Assert (Ada.Directories.Exists (Link_Path), "a hard link is created next to the source");
      Assert (not Hostkit.Fs.Is_Link (Link_Path), "a hard link is a regular directory entry");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Link_Path),
         Project_Tools.Files.Read_Raw_File (Source),
         "the hard link shares the original contents");
      Assert (Files.Model.Undo_Available (Model), "undo is available after creating a hard link");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "undo of a created hard link succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created hard link");
      Assert (Ada.Directories.Exists (Source), "undo keeps the original file");

      --  A later selected source can disappear after the listing was loaded.
      --  The earlier committed link must still be visible and covered by the
      --  batch's single Undo entry when that happens.
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "a.txt"), "first");
      Write_File (Join (Dir, "b.txt"), "second");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Files.Operations.Clear_Undo (Model);
      Files.Model.Select_All_Visible (Model);
      Ada.Directories.Delete_File (Join (Dir, "b.txt"));
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Create_Hardlink_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Failed,
         "a partial link batch refreshes and retains one undoable committed link: status");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.link.failed",
         "a partial link batch refreshes and retains one undoable committed link: error key");
      Assert
        (Ada.Directories.Exists (Join (Dir, "a (link).txt")),
         "a partial link batch refreshes and retains one undoable committed link: link created");
      Assert
        (Files.Model.Select_By_Name (Model, "a (link).txt"),
         "a partial link batch refreshes and retains one undoable committed link: link listed");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_From_Paths (Model).Length),
         1,
         "a partial link batch refreshes and retains one undoable committed link: Undo paths");
      Routed := Files.Controller.Execute_Command
        (Files.Commands.Undo_Command, Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success
         and then not Ada.Directories.Exists (Join (Dir, "a (link).txt")),
         "Undo removes the committed prefix of a partial link batch");
   end Test_Create_Hardlink_Operation;
