with Ada.Streams;
with Files.Images.Netpbm;
with Files.Types;
with Interfaces;
separate (Files_Suite.Operations)
   --  The one Netpbm reader: fields split on blanks and on # comments ended
   --  by either line break, numbers that refuse anything but digits and an
   --  overflow, samples scaled from any maximum, and the P6 header written.
   procedure Test_Netpbm_Fields (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element_Array;
      Text  : constant String := "P3 # a comment" & ASCII.CR & "2#x" & ASCII.LF & "  3" & ASCII.HT & "65535";
      At_B  : Positive := Text'First;
      First : Positive;
      Last  : Natural;
      Value : Natural;

      function Next return String is
      begin
         Files.Images.Netpbm.Next_Field (Text, At_B, First, Last);
         return Text (First .. Last);
      end Next;
   begin
      Assert_Equal (Next, "P3", "the magic number");
      Assert_Equal (Next, "2", "a comment ended by a carriage return, then a field a # ends");
      Assert_Equal (Next, "3", "a comment to the line feed, then blanks and a tab");
      Assert_Equal (Next, "65535", "the last field");
      Assert_Equal (Next, "", "nothing after the last");

      Assert (Files.Images.Netpbm.Natural_Of ("0042", Value) and then Value = 42, "digits read as a number");
      declare
         Ignored : Natural;
      begin
         Assert (not Files.Images.Netpbm.Natural_Of ("", Ignored), "an empty field is no number");
      end;
      declare
         Ignored : Natural;
      begin
         Assert (not Files.Images.Netpbm.Natural_Of ("+1", Ignored), "a sign is refused");
      end;
      declare
         Ignored : Natural;
      begin
         Assert (not Files.Images.Netpbm.Natural_Of ("99999999999999999999", Ignored), "an overflow is refused");
      end;

      Assert (Files.Images.Netpbm.Channel (65_535, 65_535) = 255, "a 16-bit maximum scales to 255");
      Assert (Files.Images.Netpbm.Channel (32_768, 65_535) = 127, "a 16-bit half scales to 127");
      Assert (Files.Images.Netpbm.Channel (7, 15) = 119, "a 4-bit sample scales by 255/15");
      Assert (Files.Images.Netpbm.Channel (300, 255) = 255, "a sample past the maximum is clamped");
      Assert (Files.Images.Netpbm.Channel (9, 0) = 0, "no maximum gives black");

      declare
         Expected : constant String := "P6" & ASCII.LF & "4 3" & ASCII.LF & "255" & ASCII.LF;
         Header   : constant Ada.Streams.Stream_Element_Array := Files.Images.Netpbm.P6_Header (4, 3);
         Wanted   : Ada.Streams.Stream_Element_Array (1 .. Expected'Length);
      begin
         for Index in Expected'Range loop
            Wanted (Ada.Streams.Stream_Element_Offset (Index)) := Character'Pos (Expected (Index));
         end loop;
         Assert (Header = Wanted, "the P6 header names the size and an 8-bit maximum");
      end;

      --  The one P3 decoder both the thumbnail writer and the cache reader use.
      declare
         W, H : Natural;
         Rgba : Files.Types.Byte_Vectors.Vector;
      begin
         Assert
           (Files.Images.Netpbm.Decode_P3 ("P3 2 1 255  255 0 0  0 0 255", 8, 8, W, H, Rgba)
              and then W = 2 and then H = 1 and then Natural (Rgba.Length) = 8,
            "a P3 image decodes to RGBA bytes");
         Assert
           (Rgba.Element (Rgba.First_Index) = 255 and then Rgba.Element (Rgba.First_Index + 3) = 255
              and then Rgba.Element (Rgba.First_Index + 6) = 255,
            "red, its alpha, and the second pixel's blue");
         Assert
           (not Files.Images.Netpbm.Decode_P3 ("P3 2 1 255  255 0 0  0 0 255 7", 8, 8, W, H, Rgba)
              and then Rgba.Is_Empty and then W = 0,
            "a sample past the promised ones fails the image and leaves nothing");
         Assert
           (not Files.Images.Netpbm.Decode_P3 ("P3 9 1 255" & [1 .. 9 => ' ', 10 .. 36 => '0'], 8, 64, W, H, Rgba),
            "a side over the cap is refused");
         Assert
           (not Files.Images.Netpbm.Decode_P3 ("P3 3 3 255", 8, 8, W, H, Rgba),
            "so are more pixels than the cap");
         Assert
           (not Files.Images.Netpbm.Decode_P3 ("P3 1 1 3  4 0 0", 8, 8, W, H, Rgba),
            "and a sample above the image's own maximum");
      end;
   end Test_Netpbm_Fields;
