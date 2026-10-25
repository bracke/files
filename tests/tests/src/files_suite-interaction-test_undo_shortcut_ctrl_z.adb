separate (Files_Suite.Interaction)
   --  Drive undo through the GENUINE live key seam (Files.Interaction.Handle_Key)
   --  with the real Shortcut_For (Undo_Command) binding, Ctrl+Z. First establish
   --  an undoable state with a committed rename, then press Ctrl+Z and assert the
   --  seam routes to Undo_Command and the original name is restored on disk.
   procedure Test_Undo_Shortcut_Ctrl_Z (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "undo-key");
      Source   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Renamed  : constant String := Files_Suite.Support.Join (Dir, "summary.txt");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Source, "payload");
      Model := Loaded_Model (Dir);

      --  Confirm Ctrl+Z translates to the undo command through the shortcut table.
      declare
         Action : constant Files.Events.Input_Action :=
           Files.Events.Translate_Key (Guikit.Input.Key_Z, Ctrl);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Command_Input_Action,
            "Ctrl+Z translates to a command input action");
         Files_Suite.Support.Assert_Equal
           (Action.Command,
            Files.Commands.Undo_Command,
            "Ctrl+Z is bound to the undo command");
      end;

      --  Establish an undoable state: rename report.txt to summary.txt via the seam.
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the rename command");
      Files.Model.Set_Rename_Text (Model, "summary.txt");
      Commit_Focused_Text (Model, Settings);
      Assert (Ada.Directories.Exists (Renamed), "committing the rename writes the new name");
      Assert (Files.Model.Undo_Available (Model), "the rename records an undoable action");

      --  Press Ctrl+Z through the live key seam and assert the undo takes effect.
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_Z,
         Modifiers         => Ctrl,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Undo_Command,
         "Ctrl+Z dispatched through Handle_Key reports the undo command");
      Assert (Ada.Directories.Exists (Source), "Ctrl+Z restores the original name");
      Assert (not Ada.Directories.Exists (Renamed), "Ctrl+Z removes the renamed file");
      Assert (not Files.Model.Undo_Available (Model), "the undo consumes the undoable action");
   end Test_Undo_Shortcut_Ctrl_Z;
