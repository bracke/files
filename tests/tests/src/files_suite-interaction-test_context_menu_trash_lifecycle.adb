separate (Files_Suite.Interaction)
   procedure Test_Context_Menu_Trash_Lifecycle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result      : Files.Interaction.Interaction_Result;
      Found       : Boolean;
      Trash_Home  : constant String := Files_Suite.Support.Root & "_trash_xdg";
      Trash_File  : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Join (Trash_Home, "Trash"), "files");
      Doomed      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "doomed.txt");
      Restore_Src : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "restore-me.txt");
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Model       : Files.Model.Window_Model;
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

      --  Delete moves the item to trash and records an undoable action.
      Files_Suite.Support.Write_File (Doomed, "payload");
      Model := Loaded_Model (Files_Suite.Support.Root);
      Files_Suite.Support.Select_Name (Model, "doomed.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Delete_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the delete command");
      Assert (not Ada.Directories.Exists (Doomed), "delete moves the item out of the directory");
      Assert (Files.Model.Undo_Available (Model), "delete records an undoable action");

      --  Undo has neither a context-menu row nor a keyboard shortcut, so it is
      --  driven through the reducer's command branch, the same entry the shell
      --  uses for menu-bar commands.
      declare
         Undo_Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Undo_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Undo_Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (Ada.Directories.Exists (Doomed), "undo restores the trashed item to its original path");
      Assert (not Files.Model.Undo_Available (Model), "undo consumes the undoable action");
      --  Re-trashing would allocate a fresh trash location, so a restored trash
      --  action is undo-only and is never offered for redo.
      Assert (not Files.Model.Redo_Available (Model), "a restored-trash undo is not offered for redo");

      --  Restore From Trash, dispatched from the item menu while viewing trash.
      declare
         Mutation : Files.File_System.Mutation_Result;
         Load     : Files.File_System.Directory_Load_Result;
      begin
         Files_Suite.Support.Write_File (Restore_Src, "payload");
         Mutation := Files.File_System.Move_To_Trash (Restore_Src);
         Assert (Mutation.Success, "the restore setup moves a file into the trash");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "restore-me.txt")),
            "the restore setup stores the trashed payload");

         Load := Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
         Files.Model.Initialize
           (Model, Ada.Strings.Unbounded.To_String (Load.Path), Load.Items, Files_Suite.Support.Root);
         Files.Operations.Settle_Current_Is_Trash (Model);
         Files_Suite.Support.Select_Name (Model, "restore-me.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Restore_From_Trash_Command, Result, Found);
         Assert (Found, "the item menu offers the restore-from-trash command");
         Assert (Ada.Directories.Exists (Restore_Src), "restore returns the file to its original path");
         Assert
           (not Ada.Directories.Exists (Files_Suite.Support.Join (Trash_File, "restore-me.txt")),
            "restore removes the trashed payload");
      end;

      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_Context_Menu_Trash_Lifecycle;
