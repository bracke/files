separate (Files_Suite.Operations)
   procedure Test_Set_Permissions_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "modeable.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Set_Permissions_And_Undo", "not Files.File_System.Supports_Permissions");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert
        (Files.File_System.Set_Permissions (Target, 8#644#).Success,
         "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "modeable.txt");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#644#, "baseline permission bits are 0644");

      Assert
        (not Files.File_System.Set_Permissions (Target, 8#10_000#).Success,
         "the filesystem API rejects permission bits outside 07777");
      Result := Files.Operations.Set_Permissions_For
        (Model, 8#10_000#, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "the operation API rejects permission bits outside 07777");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#644#, "an invalid mode leaves the file unchanged");
      Assert
        (not Files.Model.Undo_Available (Model),
         "an invalid mode does not create an undo record");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "set-permissions operation succeeds");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#600#, "mode reads back as 0600 after chmod");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Permissions,
         "set-permissions records a permission undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "undo of chmod succeeds");
      Files_Suite.Support.Assert_Equal (Mode_Of (Target), 8#644#, "undo restores the previous 0644 mode");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after chmod undo");

      Select_Name (Model, "modeable.txt");
      Ada.Directories.Delete_File (Target);
      Files.Model.Set_Error (Model, "error.directory.load");
      Result := Files.Operations.Toggle_Permission_Bit (Model, 8, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed
         and then Files.Model.Last_Error_Key (Model) = "error.permissions.failed",
         "a vanished permission target replaces stale diagnostics with its read failure");
   end Test_Set_Permissions_And_Undo;
