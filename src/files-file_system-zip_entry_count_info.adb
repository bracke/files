separate (Files.File_System)
--  The entry count the archive itself records: the End Of Central Directory
--  record (PK 5 6), found by searching the file's last 64 KiB + 22 bytes (the
--  record and the longest comment) backwards, and for a ZIP64 archive the
--  ZIP64 End Of Central Directory record (PK 6 6) its locator (PK 6 7) points
--  to. Counting central-directory signatures instead counted a stored inner
--  archive's entries and any chance PK 1 2 in the data too. An archive with
--  no valid record (truncated, or not a ZIP at all) shows 0 entries, as one
--  that cannot be opened does: no number the archive does not state.
function Zip_Entry_Count_Info
  (Path    : String;
   Of_Kind : Files.Extra_Info.Kind;
   Subject : String)
   return Files.Extra_Info.Info
is
   use type GNAT.OS_Lib.Large_File_Size;
   subtype Offset is Ada.Streams.Stream_Element_Offset;

   --  The End Of Central Directory record's fixed part, and the most of the
   --  file's tail it can sit in (a comment is at most 65_535 bytes).
   Record_Length   : constant := 22;
   Tail_Limit      : constant := 65_535 + Record_Length;
   --  The ZIP64 locator's and record's fixed parts.
   Locator_Length  : constant := 20;
   Zip64_Length    : constant := 56;
   --  The 16- and 32-bit fields that say "see the ZIP64 record".
   Escape_16 : constant Long_Long_Integer := 16#FFFF#;
   Escape_32 : constant Long_Long_Integer := 16#FFFF_FFFF#;

   function Entries (Count : Natural; Capped : Boolean := False) return Files.Extra_Info.Info is
     (Files.Extra_Info.Make (Of_Kind, Subject => Subject, Count => Count, Capped => Capped));

   File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Total  : GNAT.OS_Lib.Large_File_Size;
   --  File position of the tail's first byte.
   Start  : GNAT.OS_Lib.Large_File_Size;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. Tail_Limit);
   --  The tail as read: Buffer (1 .. Filled).
   Filled : Offset := 0;

   --  Little-endian unsigned field of Width bytes at Data (At_Index); the
   --  caller has checked it lies within Data, and that an 8-byte field's
   --  top bit is clear.
   function Field
     (Data     : Ada.Streams.Stream_Element_Array;
      At_Index : Offset;
      Width    : Offset)
      return Long_Long_Integer
   is
      Value : Long_Long_Integer := 0;
   begin
      for Index in reverse At_Index .. At_Index + Width - 1 loop
         Value := Value * 256 + Long_Long_Integer (Data (Index));
      end loop;
      return Value;
   end Field;

   function Signature_At
     (Data     : Ada.Streams.Stream_Element_Array;
      At_Index : Offset;
      Third    : Ada.Streams.Stream_Element;
      Fourth   : Ada.Streams.Stream_Element)
      return Boolean is
     (Data (At_Index) = 16#50#
      and then Data (At_Index + 1) = 16#4B#
      and then Data (At_Index + 2) = Third
      and then Data (At_Index + 3) = Fourth);

   --  The 64-bit count at Data (At_Index) as Natural: saturated, and then
   --  marked Capped.
   function Count_64
     (Data     : Ada.Streams.Stream_Element_Array;
      At_Index : Offset)
      return Files.Extra_Info.Info is
     (if Data (At_Index + 7) >= 16#80#
        or else Field (Data, At_Index, 8) > Long_Long_Integer (Natural'Last)
      then Entries (Natural'Last, Capped => True)
      else Entries (Natural (Field (Data, At_Index, 8))));

   --  The ZIP64 record's entry total, read where the locator before the
   --  End Of Central Directory record at Record_Index points; Found False
   --  when there is no valid locator or record.
   procedure Read_Zip64
     (Record_Index : Offset;
      Result       : out Files.Extra_Info.Info;
      Found        : out Boolean)
   is
      Locator : constant Offset := Record_Index - Locator_Length;
      Record_Position : Long_Long_Integer;
      Data    : Ada.Streams.Stream_Element_Array (1 .. Zip64_Length);
      Got     : Offset;
   begin
      Result := Entries (0);
      Found := False;
      if Locator < Buffer'First or else not Signature_At (Buffer, Locator, 16#06#, 16#07#) then
         return;
      end if;
      --  The record's offset from the archive's start (bytes 8 .. 15).
      if Buffer (Locator + 15) >= 16#80# then
         return;
      end if;
      Record_Position := Field (Buffer, Locator + 8, 8);
      declare
         --  The record as the tail holds it, or else right before the
         --  locator (where every writer puts it: a self-extracting stub in
         --  front shifts the stated offset).
         Stated : constant Long_Long_Integer := Record_Position - Long_Long_Integer (Start) + 1;
         Before : constant Offset := Locator - Zip64_Length;
      begin
         if Stated >= Long_Long_Integer (Buffer'First)
           and then Stated + Zip64_Length - 1 <= Long_Long_Integer (Locator - 1)
           and then Signature_At (Buffer, Offset (Stated), 16#06#, 16#06#)
         then
            Data := Buffer (Offset (Stated) .. Offset (Stated) + Zip64_Length - 1);
         elsif Before >= Buffer'First and then Signature_At (Buffer, Before, 16#06#, 16#06#) then
            Data := Buffer (Before .. Before + Zip64_Length - 1);
         elsif Record_Position <= Long_Long_Integer (Total) - Zip64_Length
           and then Record_Position <= Long_Long_Integer (Long_Integer'Last)
         then
            --  Outside the tail: read it where it is stated to be.
            GNAT.OS_Lib.Lseek (File, Long_Integer (Record_Position), GNAT.OS_Lib.Seek_Set);
            Read_Descriptor (File, Data, Got);
            if Got /= Data'Last or else not Signature_At (Data, Data'First, 16#06#, 16#06#) then
               return;
            end if;
         else
            return;
         end if;
      end;
      --  Total number of entries (bytes 32 .. 39).
      Result := Count_64 (Data, Data'First + 32);
      Found := True;
   end Read_Zip64;
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return Entries (0);
   end if;
   Total := GNAT.OS_Lib.File_Length64 (File);
   if Total < 0 then
      raise Ada.Directories.Use_Error;
   end if;
   --  Only the tail is read, however large the archive.
   Start := (if Total > Tail_Limit then Total - Tail_Limit else 0);
   if Start > 0 then
      GNAT.OS_Lib.Lseek (File, -Long_Integer (Tail_Limit), GNAT.OS_Lib.Seek_End);
   end if;
   loop
      declare
         Last : Offset;
      begin
         exit when Filled = Buffer'Last;
         Read_Descriptor (File, Buffer (Filled + 1 .. Buffer'Last), Last);
         exit when Last <= Filled;
         Filled := Last;
      end;
   end loop;

   --  The last record in the file whose comment fits the file and whose
   --  central directory lies before it; a PK 5 6 in a comment or in the
   --  data is passed over.
   for Index in reverse Buffer'First .. Filled - Record_Length + 1 loop
      if Signature_At (Buffer, Index, 16#05#, 16#06#)
        and then Index + Record_Length - 1 + Offset (Field (Buffer, Index + 20, 2)) <= Filled
      then
         declare
            Count     : constant Long_Long_Integer := Field (Buffer, Index + 10, 2);
            Size      : constant Long_Long_Integer := Field (Buffer, Index + 12, 4);
            Directory : constant Long_Long_Integer := Field (Buffer, Index + 16, 4);
            Position  : constant Long_Long_Integer := Long_Long_Integer (Start) + Long_Long_Integer (Index - 1);
            Zip64     : Files.Extra_Info.Info;
            Found     : Boolean := False;
         begin
            if Count = Escape_16 or else Size = Escape_32 or else Directory = Escape_32
              or else (Index > Locator_Length
                       and then Signature_At (Buffer, Index - Locator_Length, 16#06#, 16#07#))
            then
               Read_Zip64 (Index, Zip64, Found);
            end if;
            if Found then
               Close_Read_Descriptor (File);
               return Zip64;
            elsif Count = Escape_16 then
               --  The count is in a ZIP64 record that cannot be found: an
               --  earlier record would be a stored inner archive's.
               Close_Read_Descriptor (File);
               return Entries (0);
            elsif Directory + Size <= Position then
               Close_Read_Descriptor (File);
               return Entries (Natural (Count));
            end if;
         end;
      end if;
   end loop;
   Close_Read_Descriptor (File);
   return Entries (0);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Close_Read_Descriptor (File);
      return Entries (0);
end Zip_Entry_Count_Info;
