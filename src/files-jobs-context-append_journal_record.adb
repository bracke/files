separate (Files.Jobs.Context)
procedure Append_Journal_Record
  (Name, Header : String;
   Write_Record : not null access procedure
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
is
   Journal : constant String := Hostkit.Fs.Join (To_String (Current), Name);
   Existing : constant Boolean :=
     --  refusal-safe: a refused journal is created exclusively, which fails
     Files.IO.Fs_Primitives.Entry_Exists (Journal);
   Handle : Hostkit.Lease_Files.Lease;
   Opened : Hostkit.Lease_Files.Open_Outcome;
   Buffer : aliased Memory_Output_Stream;
   Size   : Long_Long_Integer;
   Offset : Ada.Streams.Stream_Element_Offset;
begin
   if Existing then
      Opened := Hostkit.Lease_Files.Open
        (Journal, Hostkit.Lease_Files.Exclusive, Writable => True,
         Item => Handle);
   else
      Opened := Hostkit.Lease_Files.Create (Journal, Handle);
   end if;
   if Opened /= Hostkit.Lease_Files.Opened then
      raise Ada.Directories.Use_Error;
   end if;
   Size := Hostkit.Lease_Files.Size (Handle);
   if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes) then
      raise Ada.Directories.Use_Error;
   end if;
   --  Key on the content, not on whether the file existed: a first append
   --  whose write failed leaves an empty journal behind, and records added
   --  to it without a header would make every later read reject it all.
   if Size = 0 then
      String'Output (Buffer'Access, Header);
   end if;
   Write_Record (Buffer'Access);
   if Long_Long_Integer (Buffer.Last) >
     Long_Long_Integer (Max_Journal_Bytes) - Size
   then
      raise Ada.Directories.Use_Error;
   end if;
   Offset := Ada.Streams.Stream_Element_Offset (Size);
   if Buffer.Last = 0 then
      raise Ada.Directories.Use_Error;
   elsif not Hostkit.Lease_Files.Write_At
     (Handle, Buffer.Data (Buffer.Data'First .. Buffer.Last), Offset)
   then
      --  A record cut short (a full disk) is taken back off the end: the
      --  next record would follow the torn one, and a reader stops at the
      --  first record out of shape, so every record after it was lost.
      if not Hostkit.Lease_Files.Truncate (Handle, Size) then
         Files.Diagnostics.Trace ("Files.Jobs.Context", "torn_record_kept=" & Journal);
      end if;
      raise Ada.Directories.Use_Error;
   end if;
   Hostkit.Lease_Files.Release (Handle);
   Sync_Journal (Journal);
exception
   when others =>
      Hostkit.Lease_Files.Release (Handle);
      raise;
end Append_Journal_Record;
