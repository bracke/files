separate (Files.File_System.Directory)
   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Count  : Natural := 0;
      Byte_0 : Ada.Streams.Stream_Element := 0;
      Byte_1 : Ada.Streams.Stream_Element := 0;
      Byte_2 : Ada.Streams.Stream_Element := 0;
      Byte_3 : Ada.Streams.Stream_Element := 0;
      Seen   : Natural := 0;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_0 := Byte_1;
               Byte_1 := Byte_2;
               Byte_2 := Byte_3;
               Byte_3 := Buffer (Index);
               if Seen < 4 then
                  Seen := Seen + 1;
               end if;

               if Seen = 4
                 and then Byte_0 = 16#50#
                 and then Byte_1 = 16#4B#
                 and then Byte_2 = 16#01#
                 and then Byte_3 = 16#02#
               then
                  Count := Count + 1;
               end if;
            end loop;
         end if;
      end loop;
      Stream_IO.Close (File);
      return Prefix & ".entries|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return Prefix & ".entries|0";
   end Zip_Entry_Count_Token;
