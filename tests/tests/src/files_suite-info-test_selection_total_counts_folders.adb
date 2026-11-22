with Files_Suite.Listings;
with Files.Rendering.Testing;
separate (Files_Suite.Info)
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
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Selection.Select_All_Visible (Model);                       --  folder + file
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Count (Model), 2, "the folder and file are selected");

      --  Publish a measured folder size (as the background scan would), then the
      --  combined total must count it (folder 500 + file 10). Info pane stays closed.
      Files.Model.Testing.Set_Folder_Size
        (Model, Dir_Path, (Available => True, Total_Bytes => 500, others => <>));
      Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
      Assert (not Snapshot.Info_Pane_Open, "the info pane is closed");
      Files_Suite.Support.Assert_Equal
        (Snapshot.Selection_Total_Bytes,
         510,
         "the selection total counts the folder's recursive size plus the file");
      Assert (not Snapshot.Selection_Total_Pending,
              "the total is not pending once every selected folder is measured");

      --  As the hand-overs keep it: the total follows each measurement taken
      --  in by its difference, and is the one a walk of the selection gives.
      Files.Model.Folder_Sizes.Clear (Model);
      declare
         Kept    : Boolean;
         Bytes   : Long_Long_Integer;
         Pending : Boolean;

         procedure Hand_Over (Total : Long_Long_Integer) is
            Measured : Files.Folder_Size.Measurement_Vectors.Vector;
         begin
            Measured.Append
              (Files.Folder_Size.Measurement'
                 (Path   => To_Unbounded_String (Dir_Path),
                  Result => (Available => True, Total_Bytes => Total, others => <>),
                  Listed => Files.Types.Unknown_Time));
            Files.Model.Folder_Sizes.Note (Model, Measured);
         end Hand_Over;
      begin
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Assert (Snapshot.Selection_Total_Pending, "an unmeasured folder leaves the total pending");
         Hand_Over (500);
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (Kept, "a hand-over keeps the selection's total");
         Files_Suite.Support.Assert_Equal (Bytes, 510, "the kept total counts the folder and the file");
         Assert (not Pending, "and is final with every folder measured");
         Hand_Over (700);
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Files_Suite.Support.Assert_Equal (Bytes, 710, "a folder measured again moves the total by the difference");
         Files.Model.Folder_Sizes.Prune_To_Selection (Model);
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (Kept and then Bytes = 710, "pruning a selection that holds every measured folder keeps it");
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Files_Suite.Support.Assert_Equal
           (Snapshot.Selection_Total_Bytes, 710, "the snapshot shows the kept total");
         Select_Name (Model, "afile.bin");
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (not Kept, "another selection is not the one the total was kept for");
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Files_Suite.Support.Assert_Equal
           (Snapshot.Selection_Total_Bytes, 10, "and its total is summed from the selection");
      end;
   end Test_Selection_Total_Counts_Folders;
