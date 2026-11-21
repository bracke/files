with Files.Text_Encoding;
separate (Files.File_System.Content_Info)
procedure Count_Text_Lines
  (Path   : String;
   Count  : out Natural;
   Capped : out Boolean)
is
   use type Files.Text_Encoding.Utf16_Layout;

   File        : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last        : Ada.Streams.Stream_Element_Offset;
   --  A whole character unit was read (past a byte order mark), and the
   --  last one was a line feed.
   Saw_Unit    : Boolean := False;
   Last_Was_LF : Boolean := False;
   Scanned     : Long_Long_Integer := 0;
   --  Bytes of the file left unread when the scan stopped at a limit.
   More        : Boolean := False;

   --  The file's units, told by its first bytes as the encoding word is
   --  (Files.Text_Encoding): a UTF-16 file's line feed is two bytes, one of
   --  them NUL, so a byte count read its trailing NUL as one more line.
   Layout_Known : Boolean := False;
   Layout       : Files.Text_Encoding.Utf16_Layout := Files.Text_Encoding.Not_Utf16;
   --  A UTF-16 unit's first byte, waiting for its second.
   Pending      : Ada.Streams.Stream_Element := 0;
   LF           : constant Ada.Streams.Stream_Element := Character'Pos (ASCII.LF);

   function Wide return Boolean is (Layout /= Files.Text_Encoding.Not_Utf16);

   function Little_Endian return Boolean is
     (Layout in Files.Text_Encoding.Little_Endian_Marked | Files.Text_Encoding.Little_Endian);

   function Marked return Boolean is
     (Layout in Files.Text_Encoding.Little_Endian_Marked | Files.Text_Encoding.Big_Endian_Marked);

   function Layout_Of (Bytes : Ada.Streams.Stream_Element_Array) return Files.Text_Encoding.Utf16_Layout is
      Text : String (1 .. Bytes'Length);
   begin
      for Index in Bytes'Range loop
         Text (Positive (Index - Bytes'First + 1)) := Character'Val (Bytes (Index));
      end loop;
      return Files.Text_Encoding.Utf16_Layout_Of (Text);
   end Layout_Of;
begin
   Count := 0;
   Capped := False;
   File := Files.IO.Fs_Primitives.Open_Regular_Read (Path);
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
      if not Layout_Known then
         Layout := Layout_Of (Buffer (Buffer'First .. Last));
         Layout_Known := True;
      end if;
      declare
         Used : Ada.Streams.Stream_Element_Offset := Last;
      begin
         for Index in Buffer'First .. Last loop
            declare
               Byte   : constant Ada.Streams.Stream_Element := Buffer (Index);
               Offset : constant Long_Long_Integer := Scanned + Long_Long_Integer (Index - Buffer'First);
               Whole  : Boolean := True;
            begin
               if not Wide then
                  Last_Was_LF := Byte = LF;
               elsif Offset mod 2 = 0 then
                  Pending := Byte;
                  Whole := False;
               else
                  Last_Was_LF :=
                    (if Little_Endian then Pending = LF and then Byte = 0 else Pending = 0 and then Byte = LF);
               end if;
               --  A byte order mark is no character of the text.
               if Whole and then not (Marked and then Offset < 2) then
                  Saw_Unit := True;
                  if Last_Was_LF then
                     Count := Count + 1;
                     if Count >= Extra_Line_Limit then
                        Used := Index;
                        exit;
                     end if;
                  end if;
               end if;
            end;
         end loop;
         More := Used < Last;
         Scanned := Scanned + Long_Long_Integer (Used - Buffer'First + 1);
      end;
   end loop Scan;

   if Count < Extra_Line_Limit and then Saw_Unit and then not Last_Was_LF then
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
