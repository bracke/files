separate (Files_Suite.Operations)
   procedure Test_Redo_Set_Ownership_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "redo-owner.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         Files_Suite.Support.Skip ("Test_Redo_Set_Ownership_Identity", "not Files.File_System.Supports_Ownership");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "own me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "redo-owner.txt");

      --  An identity chown to the file's own uid/gid is permitted without root
      --  and exercises the undo/redo ownership plumbing.
      Result := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "identity chown succeeds");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Ownership,
         "set-ownership records an ownership undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "undo of chown succeeds");
      Assert (Files.Model.Redo_Available (Model), "chown is redoable");

      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "redo of chown succeeds");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying chown");

      declare
         New_Uid, New_Gid : Natural := 0;
         Now_Avail        : Boolean := False;
      begin
         Files.File_System.Ownership_Of (Target, New_Uid, New_Gid, Now_Avail);
         Assert (Now_Avail, "ownership is unchanged after identity chown undo and redo: ownership readable");
         Assert (New_Uid = Uid, "ownership is unchanged after identity chown undo and redo: uid");
         Assert (New_Gid = Gid, "ownership is unchanged after identity chown undo and redo: gid");
      end;
   end Test_Redo_Set_Ownership_Identity;
