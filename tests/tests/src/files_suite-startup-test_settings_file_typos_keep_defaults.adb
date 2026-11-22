with Files.Settings.Drafts;
with Files_Suite.Support.Guards;
with Guikit.Input;
with Files.Overlays.Settings_Form;
separate (Files_Suite.Startup)
   --  Hand-edited settings: a misspelt shortcut combo is skipped, so the
   --  command keeps its default binding (secondary included) instead of
   --  being unbound or taking whatever the rest of the combo names; a valid
   --  override next to it still applies. Upper-case booleans load for every
   --  flag, so "info_pane_open = TRUE" no longer rejects the whole file.
   --  The settings hold the overrides as a save would write them, so the
   --  settings pane does not take the hand-written lines for a change.
   procedure Test_Settings_File_Typos_Keep_Defaults (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Shortcuts     : Files_Suite.Support.Guards.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Settings_Path : constant String := Join (Root, "typos.conf");
      Args          : Files.Types.String_Vectors.Vector;
      Startup       : Files.Application.Startup_Result;
      use type Guikit.Input.Key_Code;
      use type Files.Commands.Shortcut;
   begin
      Reset_Root;
      Assert (not Files.Commands.Is_Valid_Shortcut_Text ("control+bogus"), "an unknown key is invalid");
      Assert (not Files.Commands.Is_Valid_Shortcut_Text ("control+shfit+5"), "a misspelt modifier is invalid");
      Assert (not Files.Commands.Is_Valid_Shortcut_Text ("control++5"), "an empty token is invalid");
      Assert (not Files.Commands.Is_Valid_Shortcut_Text ("control"), "a combo without a key is invalid");
      Assert (Files.Commands.Is_Valid_Shortcut_Text (""), "an empty combo (an unbind) is valid");
      Assert (Files.Commands.Is_Valid_Shortcut_Text ("Control+Shift+F7"), "a well-formed combo is valid");

      Write_File
        (Settings_Path,
         "[settings]" & ASCII.LF &
         "info_pane_open = TRUE" & ASCII.LF &
         "use_system_default_opener = False" & ASCII.LF &
         "[shortcuts]" & ASCII.LF &
         "shortcut = ""edit.redo|control+bogus""" & ASCII.LF &
         "shortcut = ""view.large|control+shfit+5""" & ASCII.LF &
         "shortcut = ""view.small|control+7""" & ASCII.LF);
      Startup := Files.Application.Resolve_Startup (Args, Settings_Path);
      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Errors.Length), 0, "upper-case booleans and misspelt shortcuts do not reject the file");
      Assert (Startup.Settings.Info_Pane_Open, "info_pane_open = TRUE loads as true");
      Assert (not Startup.Settings.Use_System_Default_Opener, "use_system_default_opener = False loads as false");

      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Redo_Command)
         = Files.Commands.Default_Shortcut_For (Files.Commands.Redo_Command),
         "a misspelt key leaves Redo on its default binding");
      Assert
        (Files.Commands.Secondary_Shortcut_For (Files.Commands.Redo_Command).Present,
         "a misspelt key keeps Redo's built-in secondary (control+y)");
      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Select_Large_Icons_Command).Key = Guikit.Input.Key_2,
         "a misspelt modifier does not rebind Large Icons to the key after it");
      Assert
        (Files.Commands.Shortcut_For (Files.Commands.Select_Small_Icons_Command).Key = Guikit.Input.Key_7,
         "a valid override beside the typos still applies");

      Files_Suite.Support.Assert_Equal
        (Natural (Startup.Settings.Shortcut_Overrides.Length), 1,
         "only the override that applies is held, as a save writes it");
      Files_Suite.Support.Assert_Equal
        (To_String (Startup.Settings.Shortcut_Overrides.First_Element.Command), "view.small",
         "the held override names its command");
      Assert
        (not Files.Overlays.Settings_Form.Needs_Save
           (Startup.Settings, Files.Settings.Drafts.Make_Draft (Startup.Settings)),
         "an unchanged draft of hand-edited settings needs no save");
   end Test_Settings_File_Typos_Keep_Defaults;
