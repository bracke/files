separate (Files.File_System)
function Zip_Entry_Count_Token
  (Path   : String;
   Prefix : String)
   return String
is
   use type GNAT.OS_Lib.Large_File_Size;
   File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
   Last   : Ada.Streams.Stream_Element_Offset;
   Count  : Natural := 0;
   Byte_0 : Ada.Streams.Stream_Element := 0;
   Byte_1 : Ada.Streams.Stream_Element := 0;
   Byte_2 : Ada.Streams.Stream_Element := 0;
   Byte_3 : Ada.Streams.Stream_Element := 0;
   Seen   : Natural := 0;
   Total  : GNAT.OS_Lib.Large_File_Size;
begin
   File := Files.Fs.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return Prefix & ".entries|0";
   end if;
   --  The central-directory records this counts sit at the end of the
   --  archive, so on a large file scan only its tail rather than reading
   --  gigabytes from the front on the UI thread. The count then omits any
   --  entries whose directory record falls before the window -- a lower
   --  bound the metadata line tolerates.
   Total := GNAT.OS_Lib.File_Length64 (File);
   if Total < 0 then
      raise Ada.Directories.Use_Error;
   elsif Total > GNAT.OS_Lib.Large_File_Size (Extra_Scan_Byte_Limit) then
      GNAT.OS_Lib.Lseek
        (File, -Long_Integer (Extra_Scan_Byte_Limit), GNAT.OS_Lib.Seek_End);
   end if;
   loop
      Read_Descriptor (File, Buffer, Last);
      exit when Last < Buffer'First;
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
   Close_Read_Descriptor (File);
   return Prefix & ".entries|" & Natural_Text (Count);
exception
   when others =>
      Close_Read_Descriptor (File);
      return Prefix & ".entries|0";
end Zip_Entry_Count_Token;
