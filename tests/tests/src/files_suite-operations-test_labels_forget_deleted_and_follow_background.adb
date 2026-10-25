separate (Files_Suite.Operations)
   procedure Test_Labels_Forget_Deleted_And_Follow_Background (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Gone     : constant String := Join (Root, "gone.txt");
      Folder   : constant String := Join (Root, "folder");
      Inner    : constant String := Join (Folder, "inner.txt");
      Kept     : constant String := Join (Root, "kept.txt");
      Renamed  : constant String := Join (Root, "renamed.txt");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Followed : Boolean;
      pragma Unreferenced (Step, Followed);

      procedure Show_Root (Background : Boolean) is
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, Background);
      end Show_Root;
   begin
      for Background in Boolean loop
         Reset_Root;
         Settings := Files.Settings.Default_Settings;
         Ada.Directories.Create_Path (Folder);
         Write_Binary_File (Gone, "x");
         Write_Binary_File (Inner, "y");
         Write_Binary_File (Kept, "z");
         Files.Settings.Set_Label (Settings, Gone, Files.Types.Red);
         Files.Settings.Set_Label (Settings, Inner, Files.Types.Blue);
         Files.Settings.Set_Label (Settings, Kept, Files.Types.Green);
         Files.Settings.Toggle_Favorite_Path (Settings, Folder);

         Show_Root (Background);
         Select_Name (Model, "gone.txt");
         Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected_Permanently (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Files.Settings.Label_Of (Settings, Gone) = Files.Types.No_Label
                 and then Files.Settings.Label_Of (Settings, Kept) = Files.Types.Green,
                 "a permanently deleted file's label is forgotten, others kept"
                 & (if Background then " (background)" else ""));

         Show_Root (Background);
         Select_Name (Model, "folder");
         Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected_Permanently (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Files.Settings.Label_Of (Settings, Inner) = Files.Types.No_Label
                 and then not Files.Settings.Is_Favorite (Settings, Folder),
                 "deleting a folder forgets the labels inside it and its favorite"
                 & (if Background then " (background)" else ""));

         --  A rename in the window, then its Undo in the helper.
         Show_Root (False);
         Select_Name (Model, "kept.txt");
         Files.Model.Toggle_Rename (Model);
         Files.Model.Set_Rename_Text (Model, "renamed.txt");
         Step := Files.Operations.Commit_Rename (Model, Settings);
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Renamed),
            Files.Types.Green,
            "the label follows the rename");
         Files.Model.Set_Background_Transfers (Model, Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Files.Settings.Label_Of (Settings, Kept) = Files.Types.Green
                 and then Files.Settings.Label_Of (Settings, Renamed) = Files.Types.No_Label,
                 "Undo carries the label back" & (if Background then " (background)" else ""));
      end loop;
   end Test_Labels_Forget_Deleted_And_Follow_Background;
