with Files.Model.Sort_Menu;
separate (Files_Suite.Interaction)
   --  Ctrl+'=' / Ctrl+'+' grow, Ctrl+'-' shrinks, and Ctrl+0 resets the live
   --  font size, all clamped to the supported range, through the key seam.
   procedure Test_Keyboard_Zoom (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
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
      Assert (Result.Font_Size_Changed, "the growing zoom reports a font-size change");
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
      Assert (Result.Font_Size_Changed, "the reset reports a font-size change");

      --  Clamp at the maximum: growing past the ceiling makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Max_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Equal, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Max_Font_Pixel_Size,
         "Ctrl+Equal clamps at the maximum font size");
      Assert (not Result.Font_Size_Changed, "a no-op zoom at the ceiling reports no font-size change");

      --  Clamp at the minimum: shrinking past the floor makes no change.
      Settings.Font_Pixel_Size := Files.Settings.Min_Font_Pixel_Size;
      Zoom (Guikit.Input.Key_Minus, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Settings.Font_Pixel_Size,
         Files.Settings.Min_Font_Pixel_Size,
         "Ctrl+Minus clamps at the minimum font size");
      Assert (not Result.Font_Size_Changed, "a no-op zoom at the floor reports no font-size change");

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
         "blocked keyboard zoom reports no settings or glyph change (settings changed)");
      Assert
        (not Result.Font_Size_Changed,
         "blocked keyboard zoom reports no settings or glyph change (font size changed)");
      Assert
        (not Result.Needs_Glyph_Rebuild,
         "blocked keyboard zoom reports no settings or glyph change (needs glyph rebuild)");
      Assert
        (Result.Clear_Pending_Text,
         "a blocked zoom chord still consumes its parallel character event");
      Assert (Files.Model.Sort_Menu.Is_Open (Model), "blocked zoom leaves the owning overlay open");
      Files.Model.Sort_Menu.Close (Model);

      --  A settings file that cannot be written still takes the change: the
      --  window's font follows it (the failed save is reported, not undone).
      Files_Suite.Support.Reset_Root;
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, "not-a-folder"), "x");
      declare
         Before : constant Positive := Settings.Font_Pixel_Size;
      begin
         Zoom (Guikit.Input.Key_Equal, Ctrl,
               Path => Files_Suite.Support.Join
                 (Files_Suite.Support.Join (Files_Suite.Support.Root, "not-a-folder"), "settings.conf"));
         Files_Suite.Support.Assert_Equal
           (Settings.Font_Pixel_Size, Before + 1, "an unsaved zoom still changes the font size");
         Assert (Result.Font_Size_Changed and then Result.Needs_Glyph_Rebuild,
                 "an unsaved zoom still rebuilds the glyphs");
         Assert (Result.Settings_Changed, "and still reports the settings change");
      end;
   end Test_Keyboard_Zoom;
