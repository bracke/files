with Files.Types;

--  Font discovery for text rendering startup.
package Files.Fonts is

   --  Return the available font file best suited for broad filename text.
   --
   --  This is the monospace primary loaded first into the text renderer; the
   --  frame is laid out in fixed monospace cells, so this must resolve to a
   --  monospace face.
   --
   --  @return Font path, or an empty string when no known font is present.
   function Default_Font_Path return String;

   --  Return the ordered per-glyph fallback font chain for text rendering.
   --
   --  A small curated set (monospace symbols, broad Unicode symbols, a CJK
   --  face, and a broad international face), filtered to fonts that exist and
   --  load on this system, in priority order, excluding Default_Font_Path.
   --  Callers append these to the text renderer after the monospace primary so
   --  individual codepoints missing from the primary (stars, arrows, CJK) still
   --  resolve per glyph without the whole frame flipping to a proportional face.
   --
   --  @return Ordered, de-duplicated fallback font paths.
   function Fallback_Font_Paths return Files.Types.String_Vectors.Vector;

end Files.Fonts;
