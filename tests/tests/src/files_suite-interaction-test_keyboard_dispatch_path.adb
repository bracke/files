separate (Files_Suite.Interaction)
   --  Drive the GENUINE live key-dispatch seam the shell uses --
   --  Files.Interaction.Handle_Key -- rather than the Translate_Key ->
   --  Apply_Input_Action proxy. Handle_Key runs the focus-aware controller and
   --  re-routes settings-path keys through Execute_Command, exactly as
   --  the shell's key handler did inline. Press the real Shortcut_For key codes (rule
   --  d: never invent a binding) and assert semantic outcomes (rule b).
   procedure Test_Keyboard_Dispatch_Path (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String :=
        Files_Suite.Support.Join (Files_Suite.Support.Root, "interaction-key.conf");
   begin
      Files_Suite.Support.Reset_Root;

      --  (1) View shortcut: Ctrl+3 (Shortcut_For (Select_Details)) flows through
      --  the key seam to the details-view command and switches the model view.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_3,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Select_Details_Command,
            "Ctrl+3 dispatched through Handle_Key reports the details-view command");
         Files_Suite.Support.Assert_Equal
           (Files.Model.View_Mode_Of (Model),
            Files.Types.Details,
            "the key seam switches the model to the details view");
      end;

      --  (2) Settings-path shortcut: Save_Settings_Command is key-bound to Ctrl+S
      --  (Shortcut_For). With the settings pane open the command is enabled, so
      --  the key seam must re-route it through Execute_Command -- proven by the
      --  settings-path-only follow-ups (Settings_Changed, Clear_Pending_Text) and
      --  the persisted file -- which the plain controller branch never produces.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         --  Open the pane through the same key seam (Ctrl+, =
         --  Toggle_Settings_Pane, a non-settings-path command that takes the
         --  plain controller branch) so the whole scenario stays on the seam.
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Key               => Guikit.Input.Key_Comma,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert
           (Files.Model.Settings_Pane_Is_Open (Model),
            "the settings pane is open so the Ctrl+S save command is enabled");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Key               => Guikit.Input.Key_S,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Save_Settings_Command,
            "Ctrl+S dispatched through Handle_Key reports the save-settings command");
         Assert
           (Result.Settings_Changed,
            "the key seam re-routes the save through Execute_Command and reports a settings change");
         Assert
           (Result.Clear_Pending_Text,
            "the settings-path re-route asks the shell to drop pending character input");
         Assert
           (Ada.Directories.Exists (Path),
            "the key-driven save persists the settings file to disk");
      end;

      --  (3) Toggle shortcut: Ctrl+4 (Shortcut_For (Toggle_Info_Pane)) needs a
      --  selection to be enabled. The key seam toggles the info pane in the model
      --  via the plain controller branch (no settings-path re-route).
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Gamma.md");
         Assert
           (not Files.Model.Info_Pane_Is_Open (Model),
            "the info pane starts closed before the toggle key");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_4,
            Modifiers         => Ctrl,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Toggle_Info_Pane_Command,
            "Ctrl+4 dispatched through Handle_Key reports the toggle-info-pane command");
         Assert
           (Files.Model.Info_Pane_Is_Open (Model),
            "the key seam toggles the info pane open in the model");
      end;

      --  (4) A navigation operation installs a newly loaded directory listing;
      --  the interaction result must expose that fact to every caller of the
      --  key seam, not merely change the model path silently.
      declare
         Child : constant String :=
           Files_Suite.Support.Join (Files_Suite.Support.Root, "key-nav-child");
         Model    : Files.Model.Window_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
      begin
         Ada.Directories.Create_Path (Child);
         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Child, Settings);
         begin
            Files.Model.Initialize
              (Model, Child, Load.Items, Files_Suite.Support.Root);
         end;
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_Up,
            Modifiers         => Alt,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Current_Path (Model),
            Files_Suite.Support.Root,
            "Alt+Up through the key seam navigates to the parent directory");
         Assert
           (Result.Directory_Reloaded,
            "successful key navigation reports the installed directory listing");
      end;
   end Test_Keyboard_Dispatch_Path;
