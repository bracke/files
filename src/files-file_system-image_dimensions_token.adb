separate (Files.File_System)
function Image_Dimensions_Token
  (Path     : String;
   Filetype : String)
   return String
is
   use type GNAT.OS_Lib.Large_File_Size;
   File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. 32);
   Last   : Ada.Streams.Stream_Element_Offset;

   function Is_PNG return Boolean is
   begin
      --  Width and height are meaningful only in the mandatory first IHDR
      --  chunk.  A signature alone is not enough: arbitrary bytes at these
      --  offsets must not be presented as image dimensions.
      return Last >= 24
        and then Matches_Signature (Buffer, Last, PNG_Magic)
        and then Buffer (9 .. 12) = [0, 0, 0, 13]
        and then Buffer (13 .. 16) =
          [Character'Pos ('I'), Character'Pos ('H'),
           Character'Pos ('D'), Character'Pos ('R')];
   end Is_PNG;

   function JPEG_Token return String is
      Segment_Buffer : Ada.Streams.Stream_Element_Array (1 .. 9);
      Segment_Last   : Ada.Streams.Stream_Element_Offset;
      Marker         : Ada.Streams.Stream_Element;
      Length_Value   : Natural;
      Remaining      : Natural;
      File_Length    : constant GNAT.OS_Lib.Large_File_Size :=
        GNAT.OS_Lib.File_Length64 (File);
      Scan_End       : constant GNAT.OS_Lib.Large_File_Size :=
        GNAT.OS_Lib.Large_File_Size'Min
          (File_Length,
           GNAT.OS_Lib.Large_File_Size (Extra_Scan_Byte_Limit));
      Position       : GNAT.OS_Lib.Large_File_Size := 2;

      function Can_Read (Length : Natural) return Boolean is
        (File_Length >= 0
         and then GNAT.OS_Lib.Large_File_Size (Length)
           <= Scan_End - Position);

      procedure Read_Segment
        (Data      : out Ada.Streams.Stream_Element_Array;
         Data_Last : out Ada.Streams.Stream_Element_Offset)
      is
      begin
         Read_Descriptor (File, Data, Data_Last);
         if Data_Last >= Data'First then
            Position := Position
              + GNAT.OS_Lib.Large_File_Size
                  (Data_Last - Data'First + 1);
         end if;
      end Read_Segment;
   begin
      GNAT.OS_Lib.Lseek (File, 2, GNAT.OS_Lib.Seek_Set);
      while Can_Read (1) loop
         Read_Segment (Segment_Buffer (1 .. 1), Segment_Last);
         exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;

         loop
            if not Can_Read (1) then
               return "";
            end if;
            Read_Segment (Segment_Buffer (1 .. 1), Segment_Last);
            exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;
         end loop;

         exit when Segment_Last < 1;
         Marker := Segment_Buffer (1);

         if Marker = 16#00# then
            null;
         elsif Marker in 16#D0# .. 16#D7# or else Marker = 16#01# then
            null;
         else
            exit when Marker = 16#D9# or else Marker = 16#DA#;
            if not Can_Read (2) then
               return "";
            end if;
            Read_Segment (Segment_Buffer (1 .. 2), Segment_Last);
            exit when Segment_Last < 2;
            Length_Value := U16_BE (Segment_Buffer, 1);
            exit when Length_Value < 2;

            if Marker in 16#C0# .. 16#C3# or else Marker in 16#C5# .. 16#C7#
              or else Marker in 16#C9# .. 16#CB# or else Marker in 16#CD# .. 16#CF#
            then
               if not Can_Read (5) then
                  return "";
               end if;
               Read_Segment (Segment_Buffer (1 .. 5), Segment_Last);
               if Segment_Last >= 5 then
                  return "image.dimensions|" &
                    Dimensions_Text (U16_BE (Segment_Buffer, 4), U16_BE (Segment_Buffer, 2));
               end if;
               return "";
            end if;

            Remaining := Length_Value - 2;
            if Remaining > 0 then
               if not Can_Read (Remaining) then
                  return "";
               end if;
               GNAT.OS_Lib.Lseek
                 (File, Long_Integer (Remaining), GNAT.OS_Lib.Seek_Cur);
               Position := Position
                 + GNAT.OS_Lib.Large_File_Size (Remaining);
            end if;
         end if;
      end loop;

      return "";
   end JPEG_Token;
begin
   if Filetype /= "image/png" and then Filetype /= "image/jpeg" then
      return "";
   end if;

   File := Files.Fs.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return "";
   end if;
   Read_Descriptor (File, Buffer, Last);

   if Filetype = "image/png" and then Is_PNG then
      declare
         Token : constant String := "image.dimensions|" & Dimensions_Text (U32_BE (Buffer, 17), U32_BE (Buffer, 21));
      begin
         Close_Read_Descriptor (File);
         return Token;
      end;
   elsif Filetype = "image/jpeg"
     and then Last >= 2
     and then Buffer (1) = 16#FF#
     and then Buffer (2) = 16#D8#
   then
      declare
         Token : constant String := JPEG_Token;
      begin
         Close_Read_Descriptor (File);
         return Token;
      end;
   end if;

   Close_Read_Descriptor (File);
   return "";
exception
   when others =>
      Close_Read_Descriptor (File);
      return "";
end Image_Dimensions_Token;
