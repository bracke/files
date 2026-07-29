separate (Files.File_System)
   function Image_Dimensions_Token
     (Path     : String;
      Filetype : String)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;
      use type Stream_IO.Count;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 32);
      Last   : Ada.Streams.Stream_Element_Offset;

      function Is_PNG return Boolean is
      begin
         --  Also require the 24 bytes the IHDR width/height are read from below.
         return Last >= 24 and then Matches_Signature (Buffer, Last, PNG_Magic);
      end Is_PNG;

      function JPEG_Token return String is
         Segment_Buffer : Ada.Streams.Stream_Element_Array (1 .. 9);
         Segment_Last   : Ada.Streams.Stream_Element_Offset;
         Marker         : Ada.Streams.Stream_Element;
         Length_Value   : Natural;
         Remaining      : Natural;
      begin
         Stream_IO.Set_Index (File, 3);
         while not Stream_IO.End_Of_File (File) loop
            Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
            exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;

            loop
               Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
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
               Stream_IO.Read (File, Segment_Buffer (1 .. 2), Segment_Last);
               exit when Segment_Last < 2;
               Length_Value := U16_BE (Segment_Buffer, 1);
               exit when Length_Value < 2;

               if Marker in 16#C0# .. 16#C3# or else Marker in 16#C5# .. 16#C7#
                 or else Marker in 16#C9# .. 16#CB# or else Marker in 16#CD# .. 16#CF#
               then
                  Stream_IO.Read (File, Segment_Buffer (1 .. 5), Segment_Last);
                  if Segment_Last >= 5 then
                     return "image.dimensions|" &
                       Dimensions_Text (U16_BE (Segment_Buffer, 4), U16_BE (Segment_Buffer, 2));
                  end if;
                  return "";
               end if;

               Remaining := Length_Value - 2;
               if Remaining > 0 then
                  Stream_IO.Set_Index
                    (File,
                     Stream_IO.Positive_Count (Stream_IO.Count (Stream_IO.Index (File)) + Stream_IO.Count (Remaining)));
               end if;
            end if;
         end loop;

         return "";
      end JPEG_Token;
   begin
      if Filetype /= "image/png" and then Filetype /= "image/jpeg" then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);

      if Filetype = "image/png" and then Is_PNG then
         declare
            Token : constant String := "image.dimensions|" & Dimensions_Text (U32_BE (Buffer, 17), U32_BE (Buffer, 21));
         begin
            Stream_IO.Close (File);
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
            Stream_IO.Close (File);
            return Token;
         end;
      end if;

      Stream_IO.Close (File);
      return "";
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Image_Dimensions_Token;
