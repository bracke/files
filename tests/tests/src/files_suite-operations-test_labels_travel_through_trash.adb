separate (Files_Suite.Operations)
   procedure Test_Labels_Travel_Through_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Color_Label;
      Settings   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Photo      : constant String := Join (Root, "photo.txt");
      Trash_Home : constant String := Root & "_label_trash";
      Had_Xdg    : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Old_Xdg    : constant String := Ada.Environment_Variables.Value ("XDG_DATA_HOME", "");
      Had_Back   : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Back   : constant String := Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND", "");
      Model      : Files.Model.Window_Model;
      Load       : Files.File_System.Directory_Load_Result;
      Step       : Files.Operations.Operation_Result;
      Followed   : Boolean;
      pragma Unreferenced (Step, Followed);

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;

      procedure Trash_Photo (Background : Boolean) is
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Set_Background_Transfers (Model, Background);
         Select_Name (Model, "photo.txt");
         Step := Complete_Operation (Model, Settings, Files.Operations.Delete_Selected (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
      end Trash_Photo;

      function Labeled_Anywhere return Boolean is
        (for some Entry_Label of Settings.Labels => Entry_Label.Label = Files.Types.Purple);
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Labels_Travel_Through_Trash", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      for Background in Boolean loop
         Reset_Root;
         Project_Tools.Files.Delete_Tree (Trash_Home);
         Settings := Files.Settings.Default_Settings;
         Write_Binary_File (Photo, "x");
         Files.Settings.Set_Label (Settings, Photo, Files.Types.Purple);

         Trash_Photo (Background);
         Assert (Files.Settings.Label_Of (Settings, Photo) = Files.Types.No_Label and then Labeled_Anywhere,
                 "the label went into the trash with the file" & (if Background then " (background)" else ""));
         Write_Binary_File (Photo, "a new file at the old path");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Photo),
            Files.Types.No_Label,
            "a new file at the old path inherits no label");
         Ada.Directories.Delete_File (Photo);

         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Label_Of (Settings, Photo),
            Files.Types.Purple,
            "restoring brings the label back" & (if Background then " (background)" else ""));

         Trash_Photo (Background);
         Step := Complete_Operation (Model, Settings, Files.Operations.Empty_Trash (Model, Settings));
         Followed := Files.Interaction.Follow_Path_Moves (Model, Settings, "");
         Assert (not Labeled_Anywhere, "Empty Trash forgets the label" & (if Background then " (background)" else ""));
      end loop;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Restore_Environment;
   exception
      when others =>
         Restore_Environment;
         raise;
   end Test_Labels_Travel_Through_Trash;
