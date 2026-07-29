separate (Files.File_System)
   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Total  : Natural := 0;
   begin
      if Max_Bytes = 0 then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Total < Max_Bytes loop
         Stream_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            exit when Total >= Max_Bytes;
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Natural (Buffer (Index))));
            Total := Total + 1;
         end loop;
      end loop;

      Stream_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         Safe_Close (File);
         return Ada.Strings.Unbounded.To_String (Result);
   end Read_Preview_Text;
