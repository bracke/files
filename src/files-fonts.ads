with Textrender;
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

   --  The two halves of Textrender's colour glyph seam.
   --
   --  A colour emoji is a PNG inside the font file. Textrender reads where it is
   --  but will not decode it -- that needs an inflate implementation, and other
   --  applications link the crate without wanting one -- so the decoding is
   --  supplied from here, where files already decodes images for thumbnails.
   --
   --  @param Data The encoded image, as it sits in the font.
   --  @param Width Image width when it could be read.
   --  @param Height Image height when it could be read.
   --  @return True when the dimensions were read.
   function Colour_Glyph_Image_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural)
      return Boolean;

   --  Decode a colour glyph's picture into RGBA pixels.
   --
   --  @param Data The encoded image, as it sits in the font.
   --  @param Width The width the extent reader reported.
   --  @param Height The height the extent reader reported.
   --  @param Pixels Four bytes per pixel, R, G, B, A.
   --  @return True when the picture decoded at exactly that size.
   function Decode_Colour_Glyph_Image
     (Data   : Textrender.Encoded_Image;
      Width  : Natural;
      Height : Natural;
      Pixels : out Textrender.Rgba_Buffer)
      return Boolean;

end Files.Fonts;
