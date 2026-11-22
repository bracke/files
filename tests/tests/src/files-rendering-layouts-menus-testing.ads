--  What the suite reaches of Files.Rendering.Layouts.Menus that is not part of its interface.
package Files.Rendering.Layouts.Menus.Testing is

   --  Width of the sort dropdown menu: sized to the widest sort-field label (plus
   --  the direction indicator and padding), so every row fits even though the sort
   --  button itself is only as wide as the active field's label.
   --
   --  @param Line_Height Text line height in pixels.
   --  @return Sort-menu width in pixels.
   function Sort_Menu_Width
     (Line_Height : Positive)
      return Natural;

end Files.Rendering.Layouts.Menus.Testing;
