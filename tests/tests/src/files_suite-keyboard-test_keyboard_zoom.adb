with Files.Model.Sort_Menu;
with Files.Model.Settings_Pane;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Keyboard)
   --  Ctrl+'=' / Ctrl+'+' grow, Ctrl+'-' shrinks, and Ctrl+0 resets the live
   --  font size, all clamped to the supported range, through the key seam.
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Zoom (Key : Guikit.Input.Key_Code; Mods : Guikit.Input.Modifier_Set; Path : String := "") is
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => Path,
            Key               => Key,
            Modifiers         => Mods,
            Result            => Result);
      end Zoom;
   begin
      Files_Suite.Support.Assert_Equal (Settings.Font_Pixel_Size, 16, "the default font size is the starting point");

      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Files_Suite.Support.Assert_Equal (Settings.Font_Pixel_Size, 17, "Ctrl+Equal grows the font size by one");
      Assert (Result.Settings_Changed, "the growing zoom reports a settings change");

      Zoom (Guikit.Input.Key_Equal, Ctrl_Shift);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         18,
         "Ctrl+Plus (Shift+Ctrl+Equal) also grows the font size");

      Zoom (Guikit.Input.Key_Minus, Ctrl);
      Files_Suite.Support.Assert_Equal (Settings.Font_Pixel_Size, 17, "Ctrl+Minus shrinks the font size by one");

      Settings.Font_Pixel_Size := 24;
      Zoom (Guikit.Input.Key_0, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Default_Font_Pixel_Size,
         "Ctrl+0 resets to the default size");
      Assert (Result.Settings_Changed, "the reset reports a settings change");

      --  Clamp at the maximum: growing past the ceiling makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Max_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Max_Font_Pixel_Size,
         "Ctrl+Equal clamps at the maximum font size");
      Assert (not Result.Settings_Changed, "a no-op zoom at the ceiling reports no settings change");

      --  Clamp at the minimum: shrinking past the floor makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Min_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Minus, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Min_Font_Pixel_Size,
         "Ctrl+Minus clamps at the minimum font size");
      Assert (not Result.Settings_Changed, "a no-op zoom at the floor reports no settings change");

      --  Zoom is background UI state and must obey the same ownership rule as
      --  scrolling, clicks, and drops while a modal overlay is open.
      Settings.Font_Pixel_Size := Files.Settings.Default_Font_Pixel_Size;
      Files.Model.Sort_Menu.Toggle (Model);
      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Default_Font_Pixel_Size,
         "an input-owning overlay blocks keyboard zoom behind it");
      Assert
        (not Result.Settings_Changed,
         "blocked keyboard zoom reports no settings change");
      Assert
        (Result.Clear_Pending_Text,
         "a blocked zoom chord still consumes its parallel character event");
      Assert (Files.Model.Sort_Menu.Is_Open (Model), "blocked zoom leaves the owning overlay open");
      Files.Model.Sort_Menu.Close (Model);

      --  A settings file that cannot be written still takes the change: the
      --  window's font follows it (the failed save is reported, not undone).
      Files_Suite.Support.Disk.Reset_Root;
      Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root,
                                                                          "not-a-folder"), "x");
      declare
         Before : constant Positive := Settings.Font_Pixel_Size;
      begin
         Zoom (Guikit.Input.Key_Equal, Ctrl,
               Path => Files_Suite.Support.Disk.Join
                 (Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "not-a-folder"), "settings.conf"));
         Files_Suite.Support.Assert_Equal
           (Settings.Font_Pixel_Size, Before + 1, "an unsaved zoom still changes the font size");
         Assert (Result.Settings_Changed, "and still reports the settings change");
      end;

      --  A held chord: the press writes the file, its repeats put each size
      --  in force and leave the writing to the window once the keys rest.
      Files_Suite.Support.Disk.Reset_Root;
      Settings.Font_Pixel_Size := Files.Settings.Default_Font_Pixel_Size;
      declare
         Path : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "zoom.conf");
      begin
         Zoom (Guikit.Input.Key_Equal, Ctrl, Path => Path);
         Assert (Ada.Directories.Exists (Path) and then not Result.Zoom_Unsaved, "the press is written at once");
         Ada.Directories.Delete_File (Path);
         for Repeat in 1 .. 3 loop
            Files.Model.Settings_Pane.Note_Key_Repeat (Model, True);
            Zoom (Guikit.Input.Key_Equal, Ctrl, Path => Path);
            Files.Model.Settings_Pane.Note_Key_Repeat (Model, False);
            Assert (Result.Settings_Changed and then Result.Zoom_Unsaved,
                    "a repeat puts the size in force and says it is not written");
         end loop;
         Files_Suite.Support.Assert_Equal
           (Settings.Font_Pixel_Size, Files.Settings.Default_Font_Pixel_Size + 4, "every repeat grows the size");
         Assert (not Ada.Directories.Exists (Path), "no repeat writes the file");
      end;
   end Test_Keyboard_Zoom;
