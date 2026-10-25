separate (Files_Suite.Operations)
   procedure Test_Filetype_Extra_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;

      --  The generic fallback shown when the child count has not been computed.
      Fallback : constant String := Files.Localization.Text ("info.extra.directory");

      function Folder_Extra return String is
         Snap : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
      begin
         for Idx in 1 .. Natural (Snap.Items.Length) loop
            if Snap.Items.Element (Idx).Name = To_Unbounded_String ("sub") then
               return To_String (Snap.Items.Element (Idx).Filetype_Extra);
            end if;
         end loop;
         return "";
      end Folder_Extra;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "sub"));
      Write_File (Join (Join (Root, "sub"), "x.txt"), "hi");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "sub");

      --  Info pane closed: the child count is not computed (no subfolder opened),
      --  so the snapshot shows the cheap generic fallback rather than a count.
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Files_Suite.Support.Assert_Equal
        (Folder_Extra,
         Fallback,
         "folder shows the generic fallback, not a child count, while the info pane is closed");

      --  Info pane open: the selected folder's child count is computed lazily,
      --  replacing the fallback with the actual count detail.
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Assert (Folder_Extra /= Fallback and then Folder_Extra'Length > 0,
              "folder child count is computed lazily when the info pane is open");
   end Test_Filetype_Extra_Is_Lazy;
