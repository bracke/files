separate (Files_Suite.Operations)
   procedure Test_Selection_Total_Counts_Folders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Dir_Path : constant String := Join (Root, "adir");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir_Path);
      Write_Binary_File (Join (Root, "afile.bin"), "0123456789");   --  10-byte file
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);                       --  folder + file
      Assert (Files.Model.Selected_Count (Model) = 2, "the folder and file are selected");

      --  Publish a measured folder size (as the background scan would), then the
      --  combined total must count it (folder 500 + file 10). Info pane stays closed.
      Files.Model.Set_Folder_Size
        (Model, Dir_Path, (Available => True, Total_Bytes => 500, others => <>));
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (not Snapshot.Info_Pane_Open, "the info pane is closed");
      Assert (Snapshot.Selection_Total_Bytes = 510,
              "the selection total counts the folder's recursive size plus the file");
      Assert (not Snapshot.Selection_Total_Pending,
              "the total is not pending once every selected folder is measured");
   end Test_Selection_Total_Counts_Folders;
