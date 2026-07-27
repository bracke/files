with Files.Types;
with Guikit.Draw;

--  Prerendered file-extension labels for the large-icon extension tab.
--
--  The text renderer rasterizes glyphs at a single pixel size, so drawing the
--  extension small means downscaling those bitmaps -- which looks blurry. Here
--  each extension is rasterized once, at the small target height, into its own
--  RGBA bitmap and cached; the tab then draws that bitmap 1:1 so the small text
--  stays crisp.
package Files.Extension_Labels is

   type Label is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;   --  RGBA, row-major, top-left
   end record;

   --  Return a cached label for Ext rendered about Height pixels tall in Theme's
   --  Canvas_Color. Width = 0 when no glyphs could be produced (no font, empty
   --  extension, or an unloadable renderer).
   --  @param Ext    the file extension to render (without a leading dot)
   --  @param Height the target glyph height in pixels
   --  @param Theme  the theme whose Canvas_Color tints the glyphs
   --  @return the cached label, with Width = 0 when nothing could be rendered
   function Label_For
     (Ext    : String;
      Height : Natural;
      Theme  : Guikit.Draw.Theme_Kind)
      return Label;

end Files.Extension_Labels;
