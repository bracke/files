separate (Files.File_System)
function Pdf_Page_Count_Token (Path : String) return String is
   Marker  : constant String := "/Type /Page";
   File    : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last    : Ada.Streams.Stream_Element_Offset;
   Count   : Natural := 0;
   Scanned : Long_Long_Integer := 0;
   Matched : Natural := 0;
   Awaiting_Delimiter : Boolean := False;
   At_End  : Boolean := False;

   function Is_Delimiter (Value : Character) return Boolean is
     (Value = ' '
      or else Value = ASCII.HT
      or else Value = ASCII.LF
      or else Value = ASCII.CR
      or else Value = ASCII.VT
      or else Value = ASCII.FF
      or else Value = '/'
      or else Value = '>'
      or else Value = '<'
      or else Value = ']'
      or else Value = '[');
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return "document.kind|pdf";
   end if;
   --  Stop once enough bytes have been scanned: a huge (or huge-and-crafted)
   --  .pdf must not read to the end on the UI thread. The page count is then
   --  a lower bound, which the metadata line tolerates.
   while Scanned < Extra_Scan_Byte_Limit
   loop
      Read_Descriptor (File, Buffer, Last);
      if Last < Buffer'First then
         At_End := True;
         exit;
      end if;
      if Last >= Buffer'First then
         for Index in Buffer'First .. Last loop
            exit when Scanned = Extra_Scan_Byte_Limit;
            declare
               Value : constant Character := Character'Val (Buffer (Index));
            begin
               Scanned := Scanned + 1;
               if Awaiting_Delimiter then
                  if Is_Delimiter (Value) then
                     Count := Count + 1;
                  end if;
                  Awaiting_Delimiter := False;
               end if;

               if Value = Marker (Marker'First + Matched) then
                  Matched := Matched + 1;
                  if Matched = Marker'Length then
                     Matched := 0;
                     Awaiting_Delimiter := True;
                  end if;
               elsif Value = Marker (Marker'First) then
                  Matched := 1;
               else
                  Matched := 0;
               end if;
            end;
         end loop;
      end if;
   end loop;
   if Awaiting_Delimiter and then At_End then
      Count := Count + 1;
   end if;
   Close_Read_Descriptor (File);
   return "document.pdf.pages|" & Natural_Text (Count);
exception
   when others =>
      Close_Read_Descriptor (File);
      return "document.kind|pdf";
end Pdf_Page_Count_Token;
