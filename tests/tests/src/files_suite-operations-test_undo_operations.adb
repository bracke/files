separate (Files_Suite.Operations)
   procedure Test_Undo_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Original : constant String := Join (Root, "orig.txt");
      Renamed  : constant String := Join (Root, "renamed.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Routed   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Write_File (Original, "undo me");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "orig.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "renamed.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "rename commits before undo");
      Assert (Ada.Directories.Exists (Renamed), "rename produced the new name");
      Assert (not Ada.Directories.Exists (Original), "rename removed the old name");
      Assert (Files.Model.Undo_Available (Model), "undo is available after a rename");

      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "undo of a rename succeeds");
      Assert (Ada.Directories.Exists (Original), "undo restored the original name");
      Assert (not Ada.Directories.Exists (Renamed), "undo removed the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after undo");

      Files.Model.Clear_Undo (Model);
      Files.Model.Set_Error (Model, "error.directory.load");
      Result := Files.Operations.Undo_Last (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed
         and then Files.Model.Last_Error_Key (Model) = "error.undo.failed",
         "a direct empty Undo replaces a stale diagnostic with its failure");
      Files.Model.Set_Error (Model, "error.directory.load");
      Result := Files.Operations.Redo_Last (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed
         and then Files.Model.Last_Error_Key (Model) = "error.undo.failed",
         "a direct empty Redo replaces a stale diagnostic with its failure");
   end Test_Undo_Operations;
