separate (Files_Suite.Interaction)
   procedure Test_Sequence_Rename_Then_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "rename-seq");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Step 1: select and start rename from the item menu.
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Assert (Files.Model.Rename_Is_Active (Model), "rename starts inline editing");

      --  Step 2: set the new name and commit through the real Enter key seam.
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");
      Assert (not Ada.Directories.Exists (Source), "committing the rename removes the old name");
      Assert (not Files.Model.Rename_Is_Active (Model), "committing the rename ends inline editing");
      Assert (Files.Model.Undo_Available (Model), "the rename records an undoable action");

      --  Step 3: undo through the reducer command branch restores the original.
      Dispatch_Command (Model, Settings, Files.Commands.Undo_Command, Result);
      Assert (Ada.Directories.Exists (Source), "undo restores the original name");
      Assert (not Ada.Directories.Exists (Renamed), "undo removes the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "undo consumes the undoable action");
   end Test_Sequence_Rename_Then_Undo;
