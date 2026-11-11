separate (Files.File_System)
procedure Count_Text_Lines
  (Path   : String;
   Count  : out Natural;
   Capped : out Boolean)
is
   File        : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last        : Ada.Streams.Stream_Element_Offset;
   Saw_Byte    : Boolean := False;
   Last_Was_LF : Boolean := False;
   Scanned     : Long_Long_Integer := 0;
   --  Bytes of the file left unread when the scan stopped at a limit.
   More        : Boolean := False;
begin
   Count := 0;
   Capped := False;
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return;
   end if;
   --  The line cap alone does not bound the read: a file with few or no
   --  newlines (a multi-GB single-line log) never reaches it, so cap the
   --  bytes scanned too.
   Scan :
   loop
      if Count >= Extra_Line_Limit or else Scanned >= Extra_Scan_Byte_Limit then
         --  Stopped at a limit: the count is capped when the file goes on.
         if not More then
            Read_Descriptor (File, Buffer (Buffer'First .. Buffer'First), Last);
            More := Last >= Buffer'First;
         end if;
         exit Scan;
      end if;
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
      exit Scan when Last < Buffer'First;
      declare
         Used : Ada.Streams.Stream_Element_Offset := Last;
      begin
         for Index in Buffer'First .. Last loop
            Saw_Byte := True;
            Last_Was_LF := Buffer (Index) = Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
            if Last_Was_LF then
               Count := Count + 1;
               if Count >= Extra_Line_Limit then
                  Used := Index;
                  exit;
               end if;
            end if;
         end loop;
         More := Used < Last;
         Scanned := Scanned + Long_Long_Integer (Used - Buffer'First + 1);
      end;
   end loop Scan;

   if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then
      Count := Count + 1;
   end if;
   Capped := More;

   Close_Read_Descriptor (File);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Close_Read_Descriptor (File);
      Count := 0;
      Capped := False;
end Count_Text_Lines;
