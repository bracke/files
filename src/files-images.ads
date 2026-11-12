with Ada.Streams;
with Files.Types;

--  Raster images decoded to RGBA pixels, from a file (Quick Look and the
--  thumbnail writers) or from bytes in memory (colour emoji inside a font).
--  gdk-pixbuf does the decoding; this is the one place that binds it.
package Files.Images is

   --  The largest source that is decoded: a side, and a pixel count.
   Max_Source_Side   : constant := 4096;
   Max_Source_Pixels : constant := 4_194_304;

   --  The largest source a file decode accepts. A file is decoded scaled
   --  to Max_Decoded_Side, so camera photos far past Max_Source_Side must
   --  still pass; the bound only refuses a header that would make the
   --  loader allocate an absurd full-size buffer (about 256 MiB at most).
   Max_File_Source_Side   : constant := 32_768;
   Max_File_Source_Pixels : constant := 67_108_864;

   --  The longest side a decode is scaled to.
   Max_Decoded_Side : constant Positive := 2_048;

   --  The 8-byte signature a PNG file starts with.
   PNG_Magic : constant Ada.Streams.Stream_Element_Array (1 .. 8) :=
     --  89 'P' 'N' 'G' CR LF 1A LF
     [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];

   --  The big-endian 32-bit value at Data (First .. First + 3), as image
   --  formats store sizes and lengths. A value past Natural'Last (the high
   --  bit set, which only a crafted file has) comes back as Natural'Last, so
   --  a caller's bound refuses it rather than the arithmetic raising.
   --
   --  @param Data Bytes holding the value.
   --  @param First Index of its most significant byte.
   --  @return The value, clamped to Natural'Last.
   function U32_BE
     (Data  : Ada.Streams.Stream_Element_Array;
      First : Ada.Streams.Stream_Element_Offset)
      return Natural;

   --  Whether Data starts as a PNG must: the signature, then the IHDR chunk
   --  (length 13) first. The width and height are what IHDR declares,
   --  unchecked against any bound.
   --
   --  @param Data The file's first bytes; 24 are enough.
   --  @param Width The declared width when True.
   --  @param Height The declared height when True.
   --  @return True when Data starts as a PNG.
   function PNG_Header
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean;

   --  A decoded raster image: RGBA bytes (row-major, 4 bytes/pixel) scaled to
   --  fit within a target box while preserving aspect ratio. Available is False
   --  when the image could not be decoded.
   type Decoded_Image is record
      Available : Boolean := False;
      Width     : Natural := 0;
      Height    : Natural := 0;
      Pixels    : Files.Types.Byte_Vectors.Vector;
   end record;

   --  The pixel dimensions an encoded image declares, without decoding it.
   --
   --  For PNG this reads IHDR, which is at a fixed offset, so a caller can size a
   --  buffer before paying for a decode. Available is False when the bytes are
   --  not an image this can measure.
   --
   --  @param Data Encoded image bytes.
   --  @param Width Image width when Available.
   --  @param Height Image height when Available.
   --  @return True when the dimensions were read.
   function Image_Bytes_Extent
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean;

   --  Decode an encoded image held in memory rather than in a file.
   --
   --  The case this exists for is a picture inside a font: colour emoji glyphs
   --  are PNGs in the font file, and Textrender hands out their bytes rather than
   --  decoding them itself. Pixels come back four bytes each in R, G, B, A order,
   --  which is what an RGBA atlas wants, whatever channel count the source had.
   --
   --  @param Data Encoded image bytes.
   --  @return Decoded image; Available is False when the bytes could not be read.
   function Decode_Image_Bytes
     (Data : Ada.Streams.Stream_Element_Array)
      return Decoded_Image;

   --  Decode an image file directly to RGBA pixels, scaled to fit within
   --  Max_Size x Max_Size while preserving aspect ratio. Used for the Quick Look
   --  image preview so it renders from the original rather than the small
   --  thumbnail. Returns Available => False when decoding is unavailable.
   --
   --  @param Path Image file to decode.
   --  @param Max_Size Longest-side bound in pixels for the decoded result.
   --  @return The decoded RGBA image, or Available => False on failure.
   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image;

end Files.Images;
