--  The pure-Ada PNG reader the thumbnails use before gdk-pixbuf: 8-bit,
--  non-interlaced truecolour, as RGB (with at most one fully transparent
--  colour, tRNS) or RGBA. Anything else -- a palette, grey, another depth,
--  Adam7, an unknown critical chunk, a bad CRC, a raster that inflates to
--  more or less than it declares -- is refused, so the caller can hand the
--  file to a full decoder instead.
package Files.Images.Png is

   --  A decoded PNG: Width x Height pixels.
   type Raster is record
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Pixel_Vectors.Vector;
   end record;

   --  Decode a whole PNG file held in memory. Its sides are bounded by
   --  Max_Source_Side and its pixel count by Max_Source_Pixels.
   --
   --  @param Data The file's bytes, one per character.
   --  @param Image The decoded raster when True; empty otherwise.
   --  @return True when Data is a PNG this reader decodes, and was decoded.
   function Decode (Data : String; Image : out Raster) return Boolean;

end Files.Images.Png;
