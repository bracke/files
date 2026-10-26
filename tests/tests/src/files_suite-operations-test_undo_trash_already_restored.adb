separate (Files_Suite.Operations)
   --  Undoing a trash whose item is already back where it was (restored by
   --  hand, or by an undo a crash cut short before it recorded the step)
   --  finds it there by its identity and succeeds.
   procedure Test_Undo_Trash_Already_Restored (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Trash_Home  : constant String := Root & "_undo_restored_xdg";
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Item        : constant String := Join (Root, "kept.txt");
      Model       : Files.Model.Window_Model;
      Result      : Files.Operations.Operation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Write_File (Item, "kept");
      Files.Model.Initialize (Model, Root, Files.File_System.Load_Directory (Root, Settings).Items, Root);
      Select_Name (Model, "kept.txt");
      Result := Files.Operations.Delete_Selected (Model, Settings);
      Assert (not Ada.Directories.Exists (Item), "the item is trashed");
      Assert (Files.File_System.Restore_From_Trash
                (Join (Files.File_System.Trash_Files_Directory, "kept.txt")).Success,
              "and put back by hand");
      Result := Files.Operations.Undo_Last (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operations.Operation_Success, "undo finds the item already back");
      Assert (File_Has_Bytes (Item, "kept"), "it is where it was");
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Reset_Root;
   end Test_Undo_Trash_Already_Restored;
