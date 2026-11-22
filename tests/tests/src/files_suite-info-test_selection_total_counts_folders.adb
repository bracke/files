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

         procedure Hand_Over (Total : Long_Long_Integer; Available : Boolean := True) is
            Measured : Files.Folder_Size.Measurement_Vectors.Vector;
         begin
            Measured.Append
              (Files.Folder_Size.Measurement'
                 (Path   => To_Unbounded_String (Dir_Path),
                  Result => (Available => Available, Total_Bytes => Total, others => <>),
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

         --  A measuring that failed (unreadable, a helper that died) is no
         --  size: the total leaves it out and stays incomplete, kept or
         --  summed, until a measurement that worked replaces it.
         Hand_Over (0, Available => False);
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (Kept and then Bytes = 10 and then Pending,
                 "a failed measuring leaves the kept total incomplete:" & Bytes'Image);
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Assert (Snapshot.Selection_Total_Bytes = 10 and then Snapshot.Selection_Total_Pending,
                 "the snapshot shows it incomplete");
         Files.Model.Testing.Set_Folder_Size (Model, Dir_Path, (Available => False, others => <>));
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Assert (Snapshot.Selection_Total_Bytes = 10 and then Snapshot.Selection_Total_Pending,
                 "a walk of the selection leaves a failed measuring out too");
         Hand_Over (300);
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Assert (Snapshot.Selection_Total_Bytes = 310 and then not Snapshot.Selection_Total_Pending,
                 "a measurement that worked completes the total:" & Snapshot.Selection_Total_Bytes'Image);
         Select_Name (Model, "afile.bin");
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (not Kept, "another selection is not the one the total was kept for");
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Files_Suite.Support.Assert_Equal
           (Snapshot.Selection_Total_Bytes, 10, "and its total is summed from the selection");
      end;

      --  A folder listed twice (search results) counts once, kept or summed.
      declare
         Twice   : Files.Items.Item_Vectors.Vector := Load.Items;
         Kept    : Boolean;
         Bytes   : Long_Long_Integer;
         Pending : Boolean;
         Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      begin
         for Item of Load.Items loop
            if To_String (Item.Full_Path) = Dir_Path then
               Twice.Append (Item);
            end if;
         end loop;
         Files.Model.Initialize (Model, Root, Twice, Root);
         Files.Model.Selection.Select_All_Visible (Model);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Count (Model), 3, "the folder is selected twice, with the file");
         Measured.Append
           (Files.Folder_Size.Measurement'
              (Path   => To_Unbounded_String (Dir_Path),
               Result => (Available => True, Total_Bytes => 500, others => <>),
               Listed => Files.Types.Unknown_Time));
         Files.Model.Folder_Sizes.Note (Model, Measured);
         Files.Model.Folder_Sizes.Selection_Total (Model, Kept, Bytes, Pending);
         Assert (Kept and then Bytes = 510 and then not Pending,
                 "a folder selected twice is counted once and completes the total:" & Bytes'Image);
         Files.Model.Testing.Set_Folder_Size
           (Model, Dir_Path, (Available => True, Total_Bytes => 500, others => <>));
         Snapshot := Files.Rendering.Testing.Build_Snapshot (Model);
         Assert (Snapshot.Selection_Total_Bytes = 510 and then not Snapshot.Selection_Total_Pending,
                 "a walk of the selection counts it once too");
      end;
   end Test_Selection_Total_Counts_Folders;
