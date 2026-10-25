separate (Files_Suite.Operations)
   procedure Test_Redo_Symlink_Creation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir       : constant String := Join (Root, "redo-symlink");
      Source    : constant String := Join (Dir, "report.txt");
      Link_Path : constant String := Join (Dir, "report (link).txt");
      Load      : Files.File_System.Directory_Load_Result;
      Model     : Files.Model.Window_Model;
      Routed    : Files.Controller.Controller_Result;
      Result    : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Source, "payload");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Routed := Files.Controller.Execute_Command (Files.Commands.Create_Symlink_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "create-symlink succeeds");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "the symbolic link is created");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "undo of a created link succeeds");
      Assert (not Ada.Directories.Exists (Link_Path), "undo removes the created link");
      Assert (Files.Model.Redo_Available (Model), "a created link is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "redo of a created link succeeds");
      Assert (Hostkit.Fs.Is_Link (Link_Path), "redo re-creates the symbolic link from its source");
      Assert (Ada.Directories.Exists (Source), "redo keeps the original source item");
      Assert (Files.Model.Undo_Available (Model), "the re-created link is undoable again");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying");
   end Test_Redo_Symlink_Creation;
