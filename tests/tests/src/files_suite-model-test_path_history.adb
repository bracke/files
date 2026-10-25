separate (Files_Suite.Model)
   procedure Test_Path_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;
      Items : constant Files.File_System.Item_Vectors.Vector := Sample_Items;
   begin
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "empty back history leaves path unchanged");
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Root,
         "empty forward history leaves path unchanged");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         2,
         "history test starts with multi-selection");
      Files.Model.Navigate_To (Model, Root, Items);
      Assert (not Files.Model.Can_Go_Back (Model), "same-path navigation does not push history");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "same-path navigation clears multi-selection state");

      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/second", Items);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "navigation clears multi-selection state");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/third", Items);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         0,
         "second navigation clears multi-selection state");
      Assert (Files.Model.Can_Go_Back (Model), "back is enabled after navigation");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Begin_Create_File (Model, "history-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Set_Path_Input_Text (Model, "/tmp/bad-history-path");
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/second",
         "back restores previous path");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "back clears multi-selection state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/files_aunit/second",
         "back restores path input text");
      Assert (Files.Model.Path_Input_Is_Valid (Model), "back clears path validation state");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "back clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "back clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "back closes command palette");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "back clears focus");
      Assert (Files.Model.Can_Go_Forward (Model), "forward is enabled after back");
      Files.Model.Navigate_To (Model, "/tmp/files_aunit/branch", Items);
      Assert (not Files.Model.Can_Go_Forward (Model), "new navigation after back clears forward history");
      Files.Model.Go_Back (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/second",
         "back reaches branch origin");
      Files.Model.Begin_Create_File (Model, "forward-pending.txt");
      Files.Model.Open_Command_Palette (Model);
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/branch",
         "forward reaches branch path");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Count (Model), 0, "forward clears multi-selection state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Path_Input_Text (Model),
         "/tmp/files_aunit/branch",
         "forward restores path input text");
      Assert (not Files.Model.Temporary_Item_Is_Active (Model), "forward clears temporary create state");
      Assert (not Files.Model.Rename_Is_Active (Model), "forward clears rename state");
      Assert (not Files.Model.Command_Palette_Is_Open (Model), "forward closes command palette");
      Files_Suite.Support.Assert_Equal (Files.Model.Focus (Model), Files.Types.Focus_None, "forward clears focus");
      Files.Model.Go_Forward (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         "/tmp/files_aunit/branch",
         "forward is exhausted after branch path");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Home_Path (Model),
         "/home/test",
         "the model keeps the home path it was given");
   end Test_Path_History;
