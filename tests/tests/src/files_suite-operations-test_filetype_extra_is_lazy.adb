separate (Files_Suite.Operations)
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;

      --  The generic fallback shown while the child count is not computed.
      Fallback : constant String := Files.Localization.Text ("info.extra.directory");

      --  The detail the info pane shows for the selected folder.
      function Folder_Extra return String is
         Snap : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         return
           (if Snap.Selected_Info.Is_Empty then ""
            else To_String (Snap.Selected_Info.First_Element.Filetype_Extra));
      end Folder_Extra;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "sub"));
      Write_File (Join (Join (Root, "sub"), "x.txt"), "hi");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "sub");

      --  Info pane closed: the child count is not computed (no subfolder opened).
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Files_Suite.Support.Assert_Equal
        (Length (Files.Model.Selected_Item (Model).Filetype_Extra),
         0,
         "the folder's child count is not computed while the info pane is closed");

      --  Info pane open: the selected folder's child count is computed lazily,
      --  replacing the fallback with the actual count detail.
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Assert (Folder_Extra /= Fallback and then Folder_Extra'Length > 0,
              "folder child count is computed lazily when the info pane is open");
   end Test_Filetype_Extra_Is_Lazy;
