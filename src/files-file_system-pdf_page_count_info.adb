separate (Files.File_System)
--  Counts page objects: the name /Type, any PDF white-space (none, or
--  several -- /Type/Page is as common as /Type /Page), then the name /Page
--  ended by a delimiter, so /Pages (the page tree) does not count. Streamed
--  through a small buffer; a marker split across reads still matches.
function Pdf_Page_Count_Info (Path : String) return Files.Extra_Info.Info is
   Type_Name : constant String := "/Type";
   Page_Name : constant String := "/Page";

   --  Where the matcher is: inside /Type, past it in white-space, inside
   --  /Page, or past /Page waiting for the delimiter that ends the name.
   type Phase is (In_Type, After_Type, In_Page, After_Page);

   File    : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last    : Ada.Streams.Stream_Element_Offset;
   Count   : Natural := 0;
   Scanned : Long_Long_Integer := 0;
   State   : Phase := In_Type;
   --  Characters of the current name matched so far.
   Matched : Natural := 0;
   At_End  : Boolean := False;
   --  Bytes of the file left unread when the scan stopped at its limit.
   More    : Boolean := False;

   --  PDF white-space (ISO 32000-1, 7.2.2).
   function Is_White_Space (Value : Character) return Boolean is
     (Value = ' '
      or else Value = ASCII.HT
      or else Value = ASCII.LF
      or else Value = ASCII.CR
      or else Value = ASCII.FF
      or else Value = ASCII.NUL);

   --  What ends a name: white-space (a vertical tab too, which some writers
   --  emit) or a delimiter character.
   function Is_Delimiter (Value : Character) return Boolean is
     (Is_White_Space (Value)
      or else Value = ASCII.VT
      or else Value in '/' | '>' | '<' | ']' | '[' | '(' | ')' | '{' | '}' | '%');

   --  Start over at Value: it may begin a new /Type.
   procedure Restart (Value : Character) is
   begin
      State := In_Type;
      Matched := (if Value = '/' then 1 else 0);
   end Restart;

   procedure Feed (Value : Character) is
   begin
      case State is
         when In_Type =>
            if Value = Type_Name (Type_Name'First + Matched) then
               Matched := Matched + 1;
               if Matched = Type_Name'Length then
                  State := After_Type;
                  Matched := 0;
               end if;
            else
               Restart (Value);
            end if;
         when After_Type =>
            if Is_White_Space (Value) then
               null;
            elsif Value = '/' then
               State := In_Page;
               Matched := 1;
            else
               --  /TypeX is another name.
               Restart (Value);
            end if;
         when In_Page =>
            if Value = Page_Name (Page_Name'First + Matched) then
               Matched := Matched + 1;
               if Matched = Page_Name'Length then
                  State := After_Page;
                  Matched := 0;
               end if;
            elsif Matched = 1 and then Value = Type_Name (Type_Name'First + 1) then
               --  "/Type /T...": the slash may begin /Type again.
               State := In_Type;
               Matched := 2;
            else
               Restart (Value);
            end if;
         when After_Page =>
            if Is_Delimiter (Value) then
               Count := Count + 1;
            end if;
            Restart (Value);
      end case;
   end Feed;
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return Files.Extra_Info.Make (Files.Extra_Info.Document_Kind, Value => "pdf");
   end if;
   --  Stop once enough bytes have been scanned: a huge (or huge-and-crafted)
   --  .pdf must not be read to the end. The page count is then a lower
   --  bound, marked Capped.
   Scan :
   while Scanned < Extra_Scan_Byte_Limit loop
      Read_Descriptor (File, Buffer, Last);
      if Last < Buffer'First then
         At_End := True;
         exit Scan;
      end if;
      for Index in Buffer'First .. Last loop
         if Scanned = Extra_Scan_Byte_Limit then
            More := True;
            exit Scan;
         end if;
         Scanned := Scanned + 1;
         Feed (Character'Val (Buffer (Index)));
      end loop;
   end loop Scan;
   if not At_End and then not More then
      --  Stopped at the limit on a read boundary: is there more?
      Read_Descriptor (File, Buffer (Buffer'First .. Buffer'First), Last);
      At_End := Last < Buffer'First;
      More := not At_End;
   end if;
   if State = After_Page and then At_End then
      Count := Count + 1;
   end if;
   Close_Read_Descriptor (File);
   return Files.Extra_Info.Make (Files.Extra_Info.Pdf_Pages, Count => Count, Capped => More);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Close_Read_Descriptor (File);
      return Files.Extra_Info.Make (Files.Extra_Info.Document_Kind, Value => "pdf");
end Pdf_Page_Count_Info;
