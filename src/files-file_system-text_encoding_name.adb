separate (Files.File_System)
function Text_Encoding_Name (Path : String) return String is
   --  Classify by sampling a bounded prefix, the way file(1) does. Scanning
   --  the whole file would turn a passive directory browse into an
   --  unbounded read: this runs per regular text file via Extra_Info_Token,
   --  so a multi-GB all-valid-text file (a big log or SQL dump) would
   --  otherwise be read end to end just to render its metadata line.
   Encoding_Sample_Limit : constant := 131_072;

   File       : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last       : Ada.Streams.Stream_Element_Offset;
   Byte_Value : Natural;
   Ascii_Only : Boolean := True;
   Pending    : Natural := 0;
   First_Byte : Natural := 0;
   Step       : Natural := 0;
   Scanned    : Natural := 0;

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
   File := Files.Fs.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return "binary";
   end if;

   loop
      Read_Descriptor (File, Buffer, Last);
      exit when Last < Buffer'First;
      if Last >= Buffer'First then
         for Index in Buffer'First .. Last loop
            Byte_Value := Natural (Buffer (Index));

            if Pending > 0 then
               if not Is_Continuation (Byte_Value) then
                  Close_Read_Descriptor (File);
                  return "binary";
               elsif Step = 1 and then not Valid_First_Continuation (First_Byte, Byte_Value) then
                  Close_Read_Descriptor (File);
                  return "binary";
               end if;

               Pending := Pending - 1;
               Step := Step + 1;
            elsif Byte_Value = 0 then
               Close_Read_Descriptor (File);
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
               Close_Read_Descriptor (File);
               return "binary";
            end if;

            Scanned := Scanned + 1;
            if Scanned >= Encoding_Sample_Limit then
               --  Enough of a clean prefix to classify. A partial multi-byte
               --  sequence straddling the cap is not a defect here (Ascii_Only
               --  is already cleared), so do not fall through to the binary
               --  verdict the way a genuine mid-sequence EOF would.
               Close_Read_Descriptor (File);
               return (if Ascii_Only then "ascii" else "utf8");
            end if;
         end loop;
      end if;
   end loop;
   Close_Read_Descriptor (File);

   if Pending > 0 then
      return "binary";
   end if;

   return (if Ascii_Only then "ascii" else "utf8");
exception
   when others =>
      Close_Read_Descriptor (File);
      return "binary";
end Text_Encoding_Name;
