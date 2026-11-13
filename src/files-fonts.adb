with Files.Images;
with Files.Environment;
with Files.Diagnostics;
with Ada.Streams;
with Ada.Strings.Unbounded;

with Guikit.Fonts;
with Guikit.Text;
with Hostkit.Fs;

--  Font discovery itself is Guikit.Fonts' -- the known locations, the folder
--  scan, the loadability test and the coverage score are shared with every
--  guikit application. What is the file manager's own is where the host keeps
--  its fonts (Hostkit's answer, which on Windows is the Fonts known folder),
--  the FILES_FONT_PATH override, and the PNG decoder that lets the chain
--  include the bitmap colour emoji fonts.
package body Files.Fonts is
   use Ada.Strings.Unbounded;

   --  The host's font folders, the system's first.
   function Font_Directories return Guikit.Text.Font_Path_Vectors.Vector is
      Result : Guikit.Text.Font_Path_Vectors.Vector;
   begin
      for Folder of Hostkit.Fs.Font_Directories loop
         Result.Append (To_String (Folder));
      end loop;
      return Result;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Fonts");
         return Result;
   end Font_Directories;

   --  The two halves of Textrender's colour glyph seam, in the shape it asks
   --  for. A colour emoji is a PNG inside the font file; Textrender hands out
   --  the bytes and will not decode them, because decoding PNG means an inflate
   --  implementation and several applications link it without wanting one.
   --  files already decodes images for thumbnails, so it has the answer.

   function As_Stream_Elements
     (Data : Textrender.Encoded_Image)
      return Ada.Streams.Stream_Element_Array;

   function As_Stream_Elements
     (Data : Textrender.Encoded_Image)
      return Ada.Streams.Stream_Element_Array
   is
      Bytes : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
   begin
      for Index in Data'Range loop
         Bytes (Ada.Streams.Stream_Element_Offset (Index - Data'First + 1)) :=
           Ada.Streams.Stream_Element (Data (Index));
      end loop;

      return Bytes;
   end As_Stream_Elements;

   function Colour_Glyph_Image_Extent
     (Data   : Textrender.Encoded_Image;
      Width  : out Natural;
      Height : out Natural)
      return Boolean is
   begin
      return Files.Images.Image_Bytes_Extent (As_Stream_Elements (Data), Width, Height);
   end Colour_Glyph_Image_Extent;

   function Decode_Colour_Glyph_Image
     (Data   : Textrender.Encoded_Image;
      Width  : Natural;
      Height : Natural;
      Pixels : out Textrender.Rgba_Buffer)
      return Boolean
   is
      Decoded : constant Files.Images.Decoded_Image :=
        Files.Images.Decode_Image_Bytes (As_Stream_Elements (Data));
   begin
      Pixels := [others => 0];

      --  The size was promised by Colour_Glyph_Image_Extent before the buffer was sized, so
      --  a decode that disagrees with it would write off the end.
      if not Decoded.Available
        or else Decoded.Width /= Width
        or else Decoded.Height /= Height
        or else Natural (Decoded.Pixels.Length) /= Width * Height * 4
      then
         return False;
      end if;

      --  Byte_Vectors is indexed from 1, the buffer from 0.
      for Offset in 0 .. Natural (Decoded.Pixels.Length) - 1 loop
         exit when Pixels'First + Offset > Pixels'Last;
         Pixels (Pixels'First + Offset) :=
           Textrender.Alpha (Decoded.Pixels.Element (Offset + 1));
      end loop;

      return True;
   end Decode_Colour_Glyph_Image;

   function Default_Font_Path return String is
     (Guikit.Fonts.Default_Font_Path
        (Font_Directories => Font_Directories,
         Override         => Files.Environment.Value ("FILES_FONT_PATH")));

   function Fallback_Font_Paths return Files.Types.String_Vectors.Vector is
      Result : Files.Types.String_Vectors.Vector;
   begin
      for Path of Guikit.Fonts.Fallback_Font_Paths
        (Primary          => Default_Font_Path,
         Font_Directories => Font_Directories,
         Colour_Bitmaps   => True)
      loop
         Result.Append (To_Unbounded_String (Path));
      end loop;
      return Result;
   end Fallback_Font_Paths;

end Files.Fonts;
