separate (Files.File_System)
function Count_Text_Lines (Path : String) return Natural is
   File        : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last        : Ada.Streams.Stream_Element_Offset;
   Count       : Natural := 0;
   Saw_Byte    : Boolean := False;
   Last_Was_LF : Boolean := False;
   Scanned     : Long_Long_Integer := 0;
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return 0;
   end if;
   --  The line cap alone does not bound the read: a file with few or no
   --  newlines (a multi-GB single-line log) never reaches it, so cap the
   --  bytes scanned too.
   while Count < Extra_Line_Limit
     and then Scanned < Extra_Scan_Byte_Limit
   loop
      declare
         Remaining : constant Long_Long_Integer :=
           Extra_Scan_Byte_Limit - Scanned;
         Request : constant Ada.Streams.Stream_Element_Offset :=
           Ada.Streams.Stream_Element_Offset'Min
             (Buffer'Length,
              Ada.Streams.Stream_Element_Offset (Remaining));
      begin
         Read_Descriptor
           (File, Buffer (Buffer'First .. Buffer'First + Request - 1), Last);
      end;
      exit when Last < Buffer'First;
      if Last >= Buffer'First then
         for Index in Buffer'First .. Last loop
            Saw_Byte := True;
            Last_Was_LF := Buffer (Index) = Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
            if Last_Was_LF then
               Count := Count + 1;
               exit when Count >= Extra_Line_Limit;
            end if;
         end loop;
         Scanned := Scanned + Long_Long_Integer (Last - Buffer'First + 1);
      end if;
   end loop;

   if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then
      Count := Count + 1;
   end if;

   Close_Read_Descriptor (File);
   return Count;
exception
   when others =>
      Close_Read_Descriptor (File);
      return 0;
end Count_Text_Lines;
