separate (Files_Suite.Operations)
   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Settings   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Photo      : constant String := Join (Root, "photo.txt");
      Trash_Home : constant String := Root & "_label_trash";
      Model      : Files.Model.Window_Model;
      Load       : Files.File_System.Directory_Load_Result;
      Step       : Files.Operations.Operation_Result;
      Followed   : Boolean;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;

      function Mode (Background : Boolean) return String is
        (if Background then " (background)" else "");

      procedure Trash_Photo (Background : Boolean) is
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "photo.txt");
         Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "moving the photo to the trash succeeds" & Mode (Background));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Followed, "trashing the photo moves its stored label" & Mode (Background));
      end Trash_Photo;

      function Labeled_Anywhere return Boolean is
        (for some Entry_Label of Settings.Labels => Entry_Label.Label = Files.Types.Purple);
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Labels_Travel_Through_Trash", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      for Background in Boolean loop
         Reset_Root;
         Project_Tools.Files.Delete_Tree (Trash_Home);
         Settings := Files.Settings.Default_Settings;
         Write_Binary_File (Photo, "x");
         Files.Settings.Set_Label (Settings, Photo, Files.Types.Purple);

         Trash_Photo (Background);
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Photo),
            Files.Types.No_Label,
            "the label went into the trash with the file" & Mode (Background) & ": the old path has no label");
         Assert (Labeled_Anywhere,
                 "the label went into the trash with the file" & Mode (Background) & ": the label is still stored");
         Write_Binary_File (Photo, "a new file at the old path");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Photo),
            Files.Types.No_Label,
            "a new file at the old path inherits no label");
         Ada.Directories.Delete_File (Photo);

         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "undoing the trash succeeds" & Mode (Background));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Followed, "restoring moves the stored label back" & Mode (Background));
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Photo),
            Files.Types.Purple,
            "restoring brings the label back" & Mode (Background));

         Trash_Photo (Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "emptying the trash succeeds" & Mode (Background));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (Followed, "Empty Trash changes the stored labels" & Mode (Background));
         Assert (not Labeled_Anywhere, "Empty Trash forgets the label" & Mode (Background));
      end loop;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Labels_Travel_Through_Trash;
