--  Renderer-agnostic UTF-8 measurement helpers.
--
--  A small, domain-free copy of the UTF-8 display-width logic the GUI layout
--  needs, so Files.Gui stays independent of the application's Files.UTF8
--  package.
package Files.Gui.Utf8 is

   --  Return the display-cell count for a UTF-8 byte string.
   --
   --  Invalid bytes count as one replacement display cell.
   --
   --  @param Content UTF-8 encoded byte string.
   --  @return Number of display cells represented by Content.
   function Display_Units
     (Content : String)
      return Natural;

end Files.Gui.Utf8;
