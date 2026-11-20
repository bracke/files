with Files.Input_Actions;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Keyboard)
   procedure Test_Redo_Shortcut_Ctrl_Shift_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "redo-key");
      Source   : constant String := Files_Suite.Support.Disk.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Disk.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Disk.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Confirm Ctrl+Shift+Z translates to the redo command, distinct from the
      --  Ctrl+Z undo binding (so the two shortcuts do not collide).
      declare
         Action : constant Files.Input_Actions.Input_Action :=
           Files.Events.Translate_Key (Guikit.Input.Key_Z, Ctrl_Shift);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Input_Actions.Command_Input_Action,
            "Ctrl+Shift+Z translates to a command input action");
         Files_Suite.Support.Assert_Equal
           (Action.Command,
            Files.Commands.Redo_Command,
            "Ctrl+Shift+Z is bound to the redo command");
      end;

      --  Establish an undo/redo state: rename report.txt to summary.txt, then
      --  undo it through the Ctrl+Z seam.
      Files_Suite.Support.Models.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Files.Model.Rename.Set_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");

      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl,
         Result            => Result);
      Assert (Ada.Directories.Exists (Source), "Ctrl+Z undoes the rename");
      Assert (Files.Model.History.Redo_Available (Model), "redo becomes available after the undo");

      --  Press Ctrl+Shift+Z through the live key seam and assert the redo runs.
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl_Shift,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Redo_Command,
         "Ctrl+Shift+Z dispatched through Handle_Key reports the redo command");
      Assert (Ada.Directories.Exists (Renamed), "Ctrl+Shift+Z re-applies the rename");
      Assert (not Ada.Directories.Exists (Source), "Ctrl+Shift+Z removes the reverted name");
      Assert (not Files.Model.History.Redo_Available (Model), "the redo shortcut consumes the redo action");
   end Test_Redo_Shortcut_Ctrl_Shift_Z;
