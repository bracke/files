separate (Files_Suite.Operations)
   procedure Test_Redo_Set_Permissions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "redo-mode.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Redo_Set_Permissions", "this host has no POSIX permissions to set");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert (Files.File_System.Set_Permissions (Target, 8#644#).Success, "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "redo-mode.txt");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "chmod to 0600 succeeds");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#600#, "mode reads back as 0600 after chmod");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "undo of chmod succeeds");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#644#, "undo restores the previous 0644 mode");
      Assert (Files.Model.Redo_Available (Model), "chmod is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "redo of chmod succeeds");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#600#, "redo re-applies the new 0600 mode");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying chmod");
   end Test_Redo_Set_Permissions;
