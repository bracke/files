separate (Files_Suite.Operations)
   procedure Test_Failed_Undo_Keeps_Entry (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "vanishing.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Failed_Undo_Keeps_Entry", "not Files.File_System.Supports_Permissions");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "mode me");
      Assert
        (Files.File_System.Set_Permissions (Target, 8#644#).Success,
         "baseline chmod to 0644 succeeds");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "vanishing.txt");

      Result := Files.Operations.Set_Permissions_For (Model, 8#600#, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "set-permissions operation succeeds");
      Assert (Files.Model.Undo_Available (Model), "chmod records an undo entry");

      --  Delete the file so its restoring chmod cannot apply: the reverse now
      --  fails. Before the fix the popped entry was pushed onto neither stack
      --  and the operation silently vanished from history.
      Ada.Directories.Delete_File (Target);

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Failed,
         "undo reports failure when the reverse cannot be applied");
      Assert
        (Files.Model.Undo_Available (Model),
         "a failed undo keeps its entry on the undo stack instead of dropping it");
      Assert
        (not Files.Model.Redo_Available (Model),
         "a failed undo does not leak the entry onto the redo stack");
   end Test_Failed_Undo_Keeps_Entry;
