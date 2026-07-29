separate (Files.File_System.Directory)
   function Count_Text_Lines (Path : String) return Natural is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File        : Stream_IO.File_Type;
      Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last        : Ada.Streams.Stream_Element_Offset;
      Count       : Natural := 0;
      Saw_Byte    : Boolean := False;
      Last_Was_LF : Boolean := False;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Count < Extra_Line_Limit loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Saw_Byte := True;
               Last_Was_LF := Buffer (Index) = Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
               if Last_Was_LF then
                  Count := Count + 1;
                  exit when Count >= Extra_Line_Limit;
               end if;
            end loop;
         end if;
      end loop;

      if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then
         Count := Count + 1;
      end if;

      Stream_IO.Close (File);
      return Count;
   exception
      when others =>
         Safe_Close (File);
         return 0;
   end Count_Text_Lines;
