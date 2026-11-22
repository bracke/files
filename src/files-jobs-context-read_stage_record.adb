separate (Files.Jobs.Context)
procedure Read_Stage_Record
  (Record_Directory   : String;
   Discard_Unreadable : Boolean;
   Path, Expected     : out Files.Types.UString;
   Reading            : out Record_Reading)
is
   Input : aliased Files.IO.Lease_Streams.Input_Stream;
   Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
   Open_Result : Hostkit.Lease_Files.Open_Outcome;
begin
   Path := Null_Unbounded_String;
   Expected := Null_Unbounded_String;
   Reading := Record_Discarded;
   --  No published data means creation stopped before the staging
   --  pathname could be created, so this empty reservation is disposable.
   if Files.IO.Fs_Primitives.Entry_Is_Absent (Data) then
      return;
   end if;
   --  There, but the host will not say what it is: that may pass, so
   --  the record waits for a later pass as an unopenable one does.
   if not Hostkit.Fs.Is_Link (Data) and then Hostkit.Fs.Kind_Of (Data) = Hostkit.Fs.Missing_Entry then
      if not Discard_Unreadable then
         Reading := Record_Kept;
      end if;
      return;
   end if;
   --  A published record is always an ordinary file. Discard the record
   --  without inspecting an injected object or trusting it as a pathname.
   if Hostkit.Fs.Is_Link (Data) or else not Files.IO.Fs_Primitives.File_Exists (Data) then
      return;
   end if;
   Open_Result := Files.IO.Lease_Streams.Open (Data, Input);
   if Open_Result /= Hostkit.Lease_Files.Opened then
      Files.IO.Lease_Streams.Release (Input);
      --  Refused objects (including links and multiply-linked files)
      --  cannot become valid records. Other failures may be transient,
      --  so the bounded worker retains them for retry.
      if Open_Result /= Hostkit.Lease_Files.Refused and then not Discard_Unreadable then
         Reading := Record_Kept;
      end if;
      return;
   elsif Files.IO.Lease_Streams.Size (Input) > Max_Stage_Metadata_Bytes then
      Files.IO.Lease_Streams.Release (Input);
      return;
   end if;
   begin
      if Files.IO.Record_Fields.Input_String (Input'Access, Max_Record_Header_Length) /= Stage_Record_Header then
         Files.IO.Lease_Streams.Release (Input);
         return;
      end if;
      Path := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Input'Access, Max_Record_Path_Length));
      Expected := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Input'Access, Max_Record_Token_Length));
      if not Files.IO.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.IO.Lease_Streams.Release (Input);
      Reading := Record_Read;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         Files.IO.Lease_Streams.Release (Input);
         --  Data is published by atomic replacement and is never
         --  subsequently edited. Once it can be opened, a truncated or
         --  undecodable stream cannot become valid on a later pass. Drop
         --  only its private journal record; no decoded pathname is used
         --  and no external entry is touched.
         Path := Null_Unbounded_String;
         Expected := Null_Unbounded_String;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
      Files.IO.Lease_Streams.Release (Input);
      Reading := Record_Kept;
end Read_Stage_Record;
