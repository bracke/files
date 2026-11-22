separate (Files.Jobs.Context)
procedure Read_Journal
  (Directory, Name, Header : String;
   Shape                   : Record_Shape;
   Entries                 : out Journal_Entry_Vectors.Vector)
is
   Count : Natural := 0;
   Path : constant String := Hostkit.Fs.Join (Directory, Name);
   Input : aliased Files.IO.Lease_Streams.Input_Stream;
   Size : Long_Long_Integer;
begin
   Entries.Clear;
   if Valid_Record_Path (Directory)
     and then not Hostkit.Fs.Is_Link (Directory)
     and then Files.IO.Fs_Primitives.Entry_Is_Absent (Path)
   then
      return;
   end if;
   if not Valid_Record_Path (Directory)
     or else Hostkit.Fs.Is_Link (Directory)
     or else not Files.IO.Fs_Primitives.Directory_Exists (Directory)
     or else Files.IO.Lease_Streams.Open (Path, Input) /=
       Hostkit.Lease_Files.Opened
   then
      Files.Diagnostics.Trace ("Files.Jobs.Context", "journal_refused=" & Path);
      return;
   end if;
   Size := Files.IO.Lease_Streams.Size (Input);
   if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes)
   then
      Files.IO.Lease_Streams.Release (Input);
      return; --  A journal past the limit, or of no readable size, is not read.
   end if;
   if Files.IO.Record_Fields.Input_String
     (Input'Access, Max_Record_Header_Length) /= Header
   then
      Files.IO.Lease_Streams.Release (Input);
      return;
   end if;
   while not Files.IO.Lease_Streams.End_Of_Stream (Input) loop
      if Count = Max_Journal_Records then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Destination : constant String := Files.IO.Record_Fields.Input_String
           (Input'Access, Max_Record_Path_Length);
         Source      : constant String := Files.IO.Record_Fields.Input_String
           (Input'Access, Max_Record_Path_Length);
         Identity    : constant String := Files.IO.Record_Fields.Input_String
           (Input'Access, Max_Record_Token_Length);
         Revision    : constant String :=
           (if Shape = Creation_Record
            then Files.IO.Record_Fields.Input_String (Input'Access, Max_Record_Token_Length)
            else "");
      begin
         if not Valid_Record_Path (Destination)
           or else (not (Shape = Creation_Record and then Source = "") and then not Valid_Record_Path (Source))
           or else Identity = ""
           or else not Nul_Free (Identity)
           or else not Nul_Free (Revision)
         then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Entries.Append
           (Journal_Entry'
              (Destination   => To_Unbounded_String (Destination),
               Source        => To_Unbounded_String (Source),
               Identity      => To_Unbounded_String (Identity),
               Tree_Revision => To_Unbounded_String (Revision)));
         Count := Count + 1;
      end;
   end loop;
   Files.IO.Lease_Streams.Release (Input);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
      Files.IO.Lease_Streams.Release (Input);
end Read_Journal;
