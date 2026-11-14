with Interfaces;

--  Image files built byte by byte for the decoder and thumbnail tests: PNG
--  (header, chunks, a stored zlib stream) and JPEG.
package Files_Suite.Support.Images is

   --  A 32-bit value as four big-endian bytes, as PNG and its chunks write
   --  lengths, sizes and checksums.
   --
   --  @param Value The value.
   --  @return Its four bytes, most significant first.
   function Be32 (Value : Interfaces.Unsigned_32) return String;

   --  Convert a byte value to its Character.
   --
   --  @param Value Byte value (0 .. 255).
   --  @return The corresponding Character.
   function Byte (Value : Natural) return Character;

   --  Build a minimal PNG header for the given dimensions.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @return The encoded PNG header bytes.
   function Minimal_Png_Header (Width : Natural; Height : Natural) return String;

   --  Wrap a payload in a stored (uncompressed) zlib stream.
   --
   --  @param Payload Raw bytes to store.
   --  @return The encoded zlib stream.
   function Stored_Zlib_Stream (Payload : String) return String;

   --  Build a PNG chunk with the given type and data.
   --
   --  @param Kind Four-character chunk type.
   --  @param Data Chunk payload bytes.
   --  @return The encoded chunk (length, type, data, CRC).
   function Chunk (Kind : String; Data : String) return String;

   --  Build a minimal RGB PNG from a raw pixel payload.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @param Payload Raw pixel bytes.
   --  @return The encoded PNG file bytes.
   function Minimal_Png_RGB
     (Width   : Natural;
      Height  : Natural;
      Payload : String)
      return String;

   --  Build a minimal JPEG filled with a solid value.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @return The encoded JPEG file bytes.
   function Minimal_Jpeg_With_Fill (Width : Natural; Height : Natural) return String;

   --  A real JPEG, 8 x 8, solid red, baseline 4:4:4: none of the in-Ada
   --  decoders reads JPEG, so its pixels come from the native image loader.
   --
   --  @return The file's bytes.
   function Red_Jpeg_8x8 return String;

end Files_Suite.Support.Images;
