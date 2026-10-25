separate (Files_Suite.Interaction)
   procedure Test_Restore_From_Trash_Enablement_By_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_restore_enable_xdg";
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Model       : Files.Model.Window_Model;
      Mutation    : Files.File_System.Mutation_Result;
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

      --  A selected file in a normal directory: Restore From Trash is disabled.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Restore_From_Trash_Command),
              "Restore From Trash is listed even in a normal directory");
      Assert (not Files.Commands.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is disabled in a normal directory");

      --  After trashing and navigating into the trash files directory, a selected
      --  trashed item enables Restore From Trash.
      Mutation := Files.File_System.Move_To_Trash (Doomed);
      Assert (Mutation.Success, "the setup moves the file into the trash");
      Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
      Files.Model.Initialize
        (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
      Files.Operations.Settle_Current_Is_Trash (Model);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Assert (Files.Model.Selected_Count (Model) > 0, "the trashed item is selected in the trash view");
      Assert (Files.Commands.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is enabled with a selection inside the trash directory");

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Restore_From_Trash_Enablement_By_Context;
