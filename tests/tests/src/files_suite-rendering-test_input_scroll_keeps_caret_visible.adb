with Files.Rendering.Layouts.Testing;
separate (Files_Suite.Rendering)
   --  A focused single-line field scrolls only as far as keeping the caret
   --  visible needs: none while the caret fits, enough to show the end of
   --  overlong text when the caret is there, and never for text that fits.
   procedure Test_Input_Scroll_Keeps_Caret_Visible (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Line_Height : constant Positive := 20;
      Char_W      : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Text        : constant String (1 .. 100) := [others => 'a'];
      Width       : constant Natural := 20 * Char_W;
      Scroll      : constant Natural :=
        Files.Rendering.Layouts.Testing.Input_Scroll_Columns (Text, Text'Length, Width, Line_Height);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Layouts.Testing.Input_Scroll_Columns (Text, 5, Width, Line_Height),
         0,
         "a caret within the field needs no scroll");
      Assert (Scroll > 0 and then Text'Length - Scroll < 20,
              "a caret at the end of overlong text is scrolled into the field");
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Layouts.Testing.Input_Scroll_Columns ("short", 5, Width, Line_Height),
         0,
         "text that fits is never scrolled");
   end Test_Input_Scroll_Keeps_Caret_Visible;
