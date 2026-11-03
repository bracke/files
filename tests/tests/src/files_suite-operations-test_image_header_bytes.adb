with Files.Images;
separate (Files_Suite.Operations)
   procedure Test_Image_Header_Bytes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element_Array;
      IHDR : constant Ada.Streams.Stream_Element_Array :=
        [0, 0, 0, 13, Character'Pos ('I'), Character'Pos ('H'), Character'Pos ('D'), Character'Pos ('R')];
      Ascending : constant Ada.Streams.Stream_Element_Array (0 .. 3) := [16#00#, 16#01#, 16#02#, 16#03#];
      High_Bit  : constant Ada.Streams.Stream_Element_Array (0 .. 3) := [others => 16#FF#];
      Width, Height : Natural;
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Images.U32_BE (Ascending, 0), 16#0001_0203#, "a size reads big-endian");
      Files_Suite.Support.Assert_Equal
        (Files.Images.U32_BE (High_Bit, 0),
         Natural'Last,
         "a size with the high bit set clamps instead of raising");

      Assert
        (Files.Images.PNG_Header
           (Files.Images.PNG_Magic & IHDR & [0, 0, 0, 3, 0, 0, 0, 2], Width, Height)
         and then Width = 3 and then Height = 2,
         "a PNG header gives the declared size");
      Assert
        (not Files.Images.PNG_Header
           (Files.Images.PNG_Magic & [0, 0, 0, 13] & [16#74#, 16#45#, 16#58#, 16#74#] & [0, 0, 0, 3, 0, 0, 0, 2],
            Width, Height),
         "a signature without IHDR first is no PNG header");
      Assert
        (not Files.Images.Image_Bytes_Extent
           (Files.Images.PNG_Magic & IHDR & [16#FF#, 16#FF#, 16#FF#, 16#FF#, 0, 0, 0, 2], Width, Height),
         "a crafted huge width is refused, not raised on");
   end Test_Image_Header_Bytes;
