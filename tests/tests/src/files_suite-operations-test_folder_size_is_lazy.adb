separate (Files_Suite.Operations)
   procedure Test_Folder_Size_Is_Lazy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "sub"));
      Write_File (Join (Join (Root, "sub"), "x.txt"), "hi");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "sub");
      Files.Operations.Cancel_Folder_Scan (Model);
      declare
         Path      : constant String := To_String (Files.Model.Selected_Item (Model).Full_Path);
         Reference : constant Files.File_System.Directory_Size_Result :=
           Files.File_System.Directory_Size (Path);
      begin
         --  Selecting a folder requests its size (so the info pane and the bottom
         --  bar's total can count it), but the walk runs in a helper off the UI
         --  path: nothing is computed synchronously on the input.
         Files.Operations.Update_Folder_Size (Model, Settings);
         Assert (Files.Model.Folder_Scan_Is_Active (Model) and then Files.Model.Folder_Scan_Target (Model) = Path,
                 "selecting a folder requests its size");
         Assert (not Files.Model.Folder_Size_Cached_For (Model, Path),
                 "folder size is not computed synchronously on the input path");

         --  Advancing the background scan to completion publishes the
         --  measurement, which matches the synchronous reference.
         Drain_Folder_Sizes (Model);
         Assert (Files.Model.Folder_Size_Cached_For (Model, Path),
                 "folder size is published once the background scan finishes");
         declare
            Measured : constant Files.File_System.Directory_Size_Result :=
              Files.Model.Folder_Size_Value (Model, Path);
         begin
            Files_Suite.Support.Assert_Equal
              (Measured.Available, Reference.Available, "background folder size matches Directory_Size: availability");
            Files_Suite.Support.Assert_Equal
              (Measured.Total_Bytes, Reference.Total_Bytes, "background folder size matches Directory_Size: bytes");
            Files_Suite.Support.Assert_Equal
              (Measured.File_Count, Reference.File_Count, "background folder size matches Directory_Size: files");
            Files_Suite.Support.Assert_Equal
              (Measured.Item_Count, Reference.Item_Count, "background folder size matches Directory_Size: items");
            Files_Suite.Support.Assert_Equal
              (Measured.Capped, Reference.Capped, "background folder size matches Directory_Size: capped");
         end;
      end;
   end Test_Folder_Size_Is_Lazy;
