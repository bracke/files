separate (Files.File_System)
   function Text_Encoding_Name (Path : String) return String is
      File       : Ada.Streams.Stream_IO.File_Type;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last       : Ada.Streams.Stream_Element_Offset;
      Byte_Value : Natural;
      Ascii_Only : Boolean := True;
      Pending    : Natural := 0;
      First_Byte : Natural := 0;
      Step       : Natural := 0;

      function Valid_First_Continuation
        (Byte_Value : Natural;
         Second     : Natural)
         return Boolean is
      begin
         if Byte_Value = 16#E0# and then Second < 16#A0# then
            return False;
         elsif Byte_Value = 16#ED# and then Second > 16#9F# then
            return False;
         elsif Byte_Value = 16#F0# and then Second < 16#90# then
            return False;
         elsif Byte_Value = 16#F4# and then Second > 16#8F# then
            return False;
         end if;

         return True;
      end Valid_First_Continuation;

      function Is_Continuation (Value : Natural) return Boolean is
      begin
         return Value >= 16#80# and then Value <= 16#BF#;
      end Is_Continuation;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_Value := Natural (Buffer (Index));

               if Pending > 0 then
                  if not Is_Continuation (Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  elsif Step = 1 and then not Valid_First_Continuation (First_Byte, Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  end if;

                  Pending := Pending - 1;
                  Step := Step + 1;
               elsif Byte_Value = 0 then
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               elsif Byte_Value <= 16#7F# then
                  null;
               elsif Byte_Value in 16#C2# .. 16#DF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 1;
                  Step := 1;
               elsif Byte_Value in 16#E0# .. 16#EF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 2;
                  Step := 1;
               elsif Byte_Value in 16#F0# .. 16#F4# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 3;
                  Step := 1;
               else
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               end if;
            end loop;
         end if;
      end loop;
      Ada.Streams.Stream_IO.Close (File);

      if Pending > 0 then
         return "binary";
      end if;

      return (if Ascii_Only then "ascii" else "utf8");
   exception
      when others =>
         Safe_Close (File);
         return "binary";
   end Text_Encoding_Name;
