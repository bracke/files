with Ada.Streams;
with Interfaces;

with Files.Types;

--  Reading (and writing the header of) the text parts of a Netpbm image -- the P3 and P6 headers, and
--  P3's samples: fields separated by blanks, with # comments to the end of
--  a line. The thumbnail cache writes P6 and still reads the P3 it wrote
--  before, and a P3 file is decoded to make a thumbnail: one reader for all.
package Files.Images.Netpbm is

   --  Find the next field: skip blanks and comments, then take the run of
   --  bytes up to the next blank or #.
   --
   --  @param Text The image's bytes.
   --  @param At_Byte Where to start; left on the byte that ended the field
   --    (past Text'Last at the end), so a caller can check the delimiter.
   --  @param First First byte of the field.
   --  @param Last Last byte of the field; below First when there is none.
   procedure Next_Field
     (Text    : String;
      At_Byte : in out Positive;
      First   : out Positive;
      Last    : out Natural);

   --  A field as a number: decimal digits only, and no larger than Natural.
   --
   --  @param Field The field's text.
   --  @param Value Its value, when True.
   --  @return False for an empty field, any other byte, or an overflow.
   function Natural_Of (Field : String; Value : out Natural) return Boolean;

   --  A sample scaled from 0 .. Max_Value to a byte.
   --
   --  @param Value The sample.
   --  @param Max_Value The image's largest sample value; 0 gives 0.
   --  @return The sample as 0 .. 255.
   function Channel (Value : Natural; Max_Value : Natural) return Interfaces.Unsigned_8;

   --  The header of a binary P6 image of 8-bit samples, ready to write
   --  before its rows: "P6", the size, "255", each on a line.
   --
   --  @param Width Image width in pixels.
   --  @param Height Image height in pixels.
   --  @return The header's bytes.
   function P6_Header (Width : Positive; Height : Positive) return Ada.Streams.Stream_Element_Array;

   --  Decode an ASCII P3 image whole: the magic, a width, height and largest
   --  sample (1 .. 65535) within the caps, exactly Width * Height R G B
   --  triples each at most that sample, and nothing after them.
   --
   --  @param Text The file's text.
   --  @param Max_Side The widest and tallest an image may be.
   --  @param Max_Pixels The most pixels it may have.
   --  @param Width Its width, on success.
   --  @param Height Its height, on success.
   --  @param Rgba Its pixels as R G B A bytes (A = 255), row by row; empty
   --    on failure.
   --  @return Whether Text is such an image.
   function Decode_P3
     (Text       : String;
      Max_Side   : Positive;
      Max_Pixels : Positive;
      Width      : out Natural;
      Height     : out Natural;
      Rgba       : out Files.Types.Byte_Vectors.Vector)
      return Boolean;

end Files.Images.Netpbm;
