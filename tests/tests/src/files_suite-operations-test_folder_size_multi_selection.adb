separate (Files_Suite.Operations)
   procedure Test_Folder_Size_Multi_Selection
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Dir_A    : constant String := Join (Root, "a");
      Dir_B    : constant String := Join (Root, "b");
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir_A);
      Ada.Directories.Create_Path (Dir_B);
      Write_Binary_File (Join (Dir_A, "one.bin"), "12345");         --  5 bytes
      Write_Binary_File (Join (Dir_B, "two.bin"), "0123456789");    --  10 bytes
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.Cancel_Folder_Scan (Model);

      --  Select both folders with the info pane open, then request their sizes.
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Select_All_Visible (Model);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 2, "both folders are selected");
      Files.Operations.Update_Folder_Size (Model, Settings);

      --  Drive both queued walks to completion, publishing each result as the
      --  frame loop's Poll_All_Folder_Sizes would.
      Drain_Folder_Sizes (Model);

      Assert (Files.Model.Folder_Size_Cached_For (Model, Dir_A)
                and then Files.Model.Folder_Size_Cached_For (Model, Dir_B),
              "each selected folder has its own cached size");
      Assert (Files.Model.Folder_Size_Value (Model, Dir_A).Total_Bytes = 5
                and then Files.Model.Folder_Size_Value (Model, Dir_B).Total_Bytes = 10,
              "per-folder sizes are the recursive totals of each folder");
   end Test_Folder_Size_Multi_Selection;
