separate (Files_Suite.Interaction)
   procedure Test_Sequence_Trash_Then_Restore (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Found       : Boolean;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_trash_seq_xdg";
      Trash_File  : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Join (Trash_Home, "Trash"), "files");
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Model       : Files.Model.Window_Model;
      Load        : Files.File_System.Directory_Load_Result;
   begin
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Save (Environment, "HOME");
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");

      Files_Suite.Support.Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("HOME", Trash_Home);

      --  Step 1: delete a file to trash via the item menu.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Delete_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the delete command");
      Assert (not Ada.Directories.Exists (Doomed), "delete moves the item out of the directory");
      Assert
        (Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "doomed.txt")),
         "delete stores the payload in the trash files directory");

      --  Step 2: navigate into the trash directory and select the trashed item.
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Initialize
        (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Assert (Files.Model.Selected_Count (Model) > 0, "the trashed item is selectable in the trash view");

      --  Step 3: restore from the item menu returns the file to its origin.
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Restore_From_Trash_Command, Result, Found);
      Assert (Found, "the item menu offers the restore-from-trash command");
      Assert (Ada.Directories.Exists (Doomed), "restore returns the file to its original path");
      Assert
        (not Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "doomed.txt")),
         "restore removes the file from the trash directory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Sequence_Trash_Then_Restore;
