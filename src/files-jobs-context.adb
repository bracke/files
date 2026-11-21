with Files.Protocol_Names;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files.Bounded_Streams;
with Files.Jobs.Storage;
with Files.Fs_Primitives;
with Files.Durable_Writes;
with Files.Private_Directories;
with Files.Jobs.Process;
with Files.Durability;
with Hostkit.Durability;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.File_Identities;
with Files.Lease_Streams;
with Files.Path_Checks;
with Ada.Real_Time;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;

package body Files.Jobs.Context is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Files.Private_Directories.Create_Result;
   use type Hostkit.Durability.Outcome;
   use type Hostkit.Fs.Entry_Kind;
   use type Hostkit.Lease_Files.Open_Outcome;

   package Destination_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

   Stage_Record_Header : constant String := "files-stage-3";
   Created_Record_Header : constant String := "files-created-3";
   Created_Intent_Header : constant String := "files-created-intent-1";
   Moved_Record_Header   : constant String := "files-moved-1";
   Moved_Intent_Header   : constant String := "files-moved-intent-1";
   Max_Record_Header_Length : constant := Files.Bounded_Streams.Max_Header_Length;
   Max_Record_Path_Length : constant := Files.Bounded_Streams.Max_Path_Length;
   Max_Record_Token_Length : constant := Files.Bounded_Streams.Max_Token_Length;
   Max_Stage_Metadata_Bytes : constant := 64 * 1024;
   Max_Journal_Bytes : constant := 64 * 1024 * 1024;
   Max_Journal_Records : constant := 100_000;
   Encoded_String_Overhead : constant := 16;
   Max_Append_Bytes : constant :=
     2 * Max_Record_Path_Length + 2 * Max_Record_Token_Length
       + Max_Record_Header_Length + 5 * Encoded_String_Overhead;
   --  How often a helper reads its cancellation marker: often enough that a
   --  cancel stops the work at once to a person, seldom enough that a copy
   --  checking every chunk does not open a file every chunk.
   Cancel_Check_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (100);

   --  What the marker said last, and when it is read again. A cancel is
   --  never taken back, so once seen it stays.
   protected Cancellation is
      --  Due is True for the one caller that is to read the marker now; the
      --  next read is then Cancel_Check_Interval later.
      procedure Claim (Now : Ada.Real_Time.Time; Due : out Boolean);
      procedure Latch;
      function Latched return Boolean;
      --  A new job directory: nothing seen, read at once.
      procedure Forget;
   private
      Seen       : Boolean := False;
      Next_Check : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end Cancellation;

   protected body Cancellation is
      procedure Claim (Now : Ada.Real_Time.Time; Due : out Boolean) is
         use type Ada.Real_Time.Time;
      begin
         Due := not Seen and then Now >= Next_Check;
         if Due then
            Next_Check := Now + Cancel_Check_Interval;
         end if;
      end Claim;

      procedure Latch is
      begin
         Seen := True;
      end Latch;

      function Latched return Boolean is (Seen);

      procedure Forget is
      begin
         Seen := False;
         Next_Check := Ada.Real_Time.Time_First;
      end Forget;
   end Cancellation;

   Foreground_Job : Files.Jobs.Process.Session;
   Foreground_Paths : Files.Types.String_Vectors.Vector;
   Foreground_Records : Files.Types.String_Vectors.Vector;

   subtype Append_Buffer is Ada.Streams.Stream_Element_Array
     (1 .. Ada.Streams.Stream_Element_Offset (Max_Append_Bytes));

   type Memory_Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Data : Append_Buffer := [others => 0];
      Last : Ada.Streams.Stream_Element_Offset := 0;
   end record;

   overriding procedure Read
     (Stream : in out Memory_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Memory_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

   overriding procedure Read
     (Stream : in out Memory_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   overriding procedure Write
     (Stream : in out Memory_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array) is
   begin
      if Ada.Streams.Stream_Element_Offset (Item'Length) >
        Stream.Data'Last - Stream.Last
      then
         raise Ada.Directories.Use_Error;
      end if;
      for Value of Item loop
         Stream.Last := Stream.Last + 1;
         Stream.Data (Stream.Last) := Value;
      end loop;
   end Write;

   function Nul_Free (Value : String) return Boolean renames Files.Path_Checks.Nul_Free;

   --  Whether Path is absolute and short enough to be read back from a record.
   function Valid_Record_Path (Path : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Path, Max_Record_Path_Length));

   procedure Sync_Journal (Path : String);

   procedure Publish_Record
     (Target : String;
      Write_Record : not null access procedure
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class)) is
   begin
      --  Write_And_Publish refuses a Target that is a link or not a file.
      if not Files.Durable_Writes.Published (Files.Durable_Writes.Write_And_Publish (Target, Write_Record)) then
         raise Ada.Directories.Use_Error;
      end if;
   end Publish_Record;

   procedure Append_Journal_Record
     (Name, Header : String;
      Write_Record : not null access procedure
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
   is
      Journal : constant String := Hostkit.Fs.Join (To_String (Current), Name);
      Existing : constant Boolean :=
        --  refusal-safe: a refused journal is created exclusively, which fails
        Files.Fs_Primitives.Entry_Exists (Journal);
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

   --  Flush a journal just appended to, then its folder. The record is
   --  written either way, so a failed flush does not fail the append: the
   --  record holds unless the machine stops before the device catches up.
   --  It is traced, for a dying disk shows here first.
   procedure Sync_Journal (Path : String) is
      File_Sync : constant Hostkit.Durability.Outcome := Files.Durability.Sync_File (Path);
   begin
      if File_Sync = Hostkit.Durability.Failed then
         Files.Diagnostics.Trace ("Files.Jobs.Context", "journal_sync_failed=" & Path);
      elsif File_Sync = Hostkit.Durability.Synced
        and then Files.Durability.Sync_Directory (Files.Fs_Primitives.Parent_Directory (Path)) =
          Hostkit.Durability.Failed
      then
         Files.Diagnostics.Trace ("Files.Jobs.Context", "journal_folder_sync_failed=" & Path);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
   end Sync_Journal;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String);

   procedure Remove_Record (Record_Directory : String) is
   begin
      if Record_Directory /= ""
        and then not Hostkit.Fs.Is_Link (Record_Directory)
        and then Files.Fs_Primitives.Directory_Exists (Record_Directory)
      then
         Files.Fs_Primitives.Delete_Tree_If_Present (Record_Directory);
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
   end Remove_Record;

   procedure Initialize (Directory : String) is
   begin
      if Directory /= "" and then not Valid_Record_Path (Directory) then
         raise Ada.Directories.Use_Error;
      end if;
      Current := To_Unbounded_String (Directory);
      Cancellation.Forget;
   end Initialize;

   procedure Shutdown is
   begin
      Files.Jobs.Process.Reset (Foreground_Job);
      Foreground_Paths.Clear;
      Foreground_Records.Clear;
   end Shutdown;

   function Directory return String is (To_String (Current));

   function Cancelled return Boolean is
      Due : Boolean;
   begin
      if Length (Current) = 0 then
         return False;
      elsif Cancellation.Latched then
         return True;
      end if;
      Cancellation.Claim (Ada.Real_Time.Clock, Due);
      if Due and then Files.Jobs.Process.Cancellation_Requested (To_String (Current)) then
         Cancellation.Latch;
         return True;
      end if;
      return False;
   end Cancelled;

   function Stage_Owner_Directory return String is
   begin
      if Length (Current) > 0 then
         return To_String (Current);
      end if;
      if not Files.Jobs.Process.Active (Foreground_Job) then
         Files.Jobs.Process.Reserve (Foreground_Job);
      end if;
      return Files.Jobs.Process.Path (Foreground_Job, "");
   end Stage_Owner_Directory;

   procedure Write_Stage_Record
     (Record_Directory, Path, Identity : String)
   is
      Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Stage_Record_Header);
         String'Output (Stream, Path);
         String'Output (Stream, Identity);
      end Write;
   begin
      if not Valid_Record_Path (Record_Directory)
        or else not Valid_Record_Path (Path)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Publish_Record (Data, Write'Access);
   end Write_Stage_Record;

   function Begin_Stage_Record (Path : String) return String is
      Owner_Directory : constant String := Stage_Owner_Directory;
      Stages : constant String := Hostkit.Fs.Join (Owner_Directory, Files.Protocol_Names.Stages_Directory);
   begin
      if Files.Private_Directories.Try_Create (Stages) =
        Files.Private_Directories.Collision
        and then (Hostkit.Fs.Is_Link (Stages) or else not Files.Fs_Primitives.Directory_Exists (Stages))
      then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Record_Directory : constant String :=
              Hostkit.Fs.Join (Stages, "stage-" & Image (2 .. Image'Last));
         begin
            if Files.Private_Directories.Try_Create (Record_Directory) =
              Files.Private_Directories.Collision
            then
               goto Continue;
            end if;
            begin
               --  Publish the intended pathname before creating it. A crash
               --  can therefore leave an unfinished record, never an
               --  undiscoverable staging directory.
               Write_Stage_Record (Record_Directory, Path, "");
               return Record_Directory;
            exception
               when others =>
                  Remove_Record (Record_Directory);
                  raise;
            end;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   end Begin_Stage_Record;

   function Create_Stage (Parent : String) return String is
   begin
      if not Valid_Record_Path (Parent) then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Image : constant String := Natural'Image (N);
            Candidate : constant String :=
              Hostkit.Fs.Join (Parent, Files.Protocol_Names.Work_Stage_Prefix & Image (2 .. Image'Last));
            Identity : Files.Types.UString;
            Record_Directory : Files.Types.UString;
         begin
            Record_Directory := To_Unbounded_String (Begin_Stage_Record (Candidate));
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               Remove_Record (To_String (Record_Directory));
               goto Continue;
            end if;
            begin
               Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               if Length (Identity) = 0 then
                  raise Ada.Directories.Use_Error;
               end if;
            exception
               when others =>
                  begin
                     Files.Fs_Primitives.Delete_Directory (Candidate);
                     Remove_Record (To_String (Record_Directory));
                  exception
                     when Swallowed : others =>
                        Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
                  end;
                  raise;
            end;
            begin
               Register_Stage_Internal
                 (Candidate, To_String (Identity), To_String (Record_Directory));
            exception
               when others =>
                  declare
                     Removed : constant Boolean :=
                       Files.Jobs.Storage.Delete_Staging_Entry
                         (Candidate, To_String (Identity));
                     pragma Unreferenced (Removed);
                  begin
                     null;
                  end;
                  if Files.Fs_Primitives.Entry_Is_Absent (Candidate) then
                     Remove_Record (To_String (Record_Directory));
                  end if;
                  raise;
            end;
            if Length (Current) = 0 then
               Foreground_Paths.Append (To_Unbounded_String (Candidate));
               Foreground_Records.Append (Record_Directory);
            end if;
            return Candidate;
            <<Continue>>
         end;
      end loop;
      raise Ada.Directories.Use_Error;
   exception
      when others =>
         if Length (Current) = 0 and then Foreground_Paths.Is_Empty
           and then Files.Jobs.Process.Active (Foreground_Job)
         then
            Files.Jobs.Process.Reset (Foreground_Job);
         end if;
         raise;
   end Create_Stage;

   --  The shape of a journal's records: a destination, a source and an
   --  identity, and for a creation a tree revision too.
   type Record_Shape is (Move_Record, Creation_Record);

   --  Append one record of Shape to the journal Name under Header. A record
   --  with a field too long for a reader to accept is not written, and the
   --  drop is traced: recovery then finds that job's change only as an
   --  unrecorded one. Raises what Append_Journal_Record raises.
   procedure Append_Record
     (Name, Header  : String;
      Shape         : Record_Shape;
      Destination   : String;
      Source        : String;
      Identity      : String;
      Tree_Revision : String := "");

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean
     renames Files.Jobs.Storage.Creation_Matches;

   procedure Record_Created (Destination : String; Source : String := "") is
   begin
      Record_Created (Destination, Source, Files.File_Identities.Token (Destination));
   end Record_Created;

   procedure Record_Created (Destination, Source, Identity : String) is
   begin
      Record_Created (Destination, Source, Identity, Files.Jobs.Storage.Tree_Revision (Destination));
   end Record_Created;

   procedure Intend_Created (Destination, Source, Identity, Tree_Revision : String) is
   begin
      if Length (Current) = 0 or else Identity = "" then
         return;
      end if;
      Append_Record
        ("created-intent", Created_Intent_Header, Creation_Record, Destination, Source, Identity, Tree_Revision);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         --  Recovery then finds this one only once it is recorded, as
         --  before intents were kept; the publication itself goes ahead.
         null;
   end Intend_Created;

   procedure Record_Created (Destination, Source, Identity, Tree_Revision : String) is
   begin
      if Length (Current) = 0
        or else not Creation_Snapshot_Matches (Destination, Identity, Tree_Revision)
      then
         return;
      end if;
      Append_Record ("created", Created_Record_Header, Creation_Record, Destination, Source, Identity, Tree_Revision);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         --  Publication already succeeded; retain its normal result even if
         --  this crash-recovery journal cannot be extended.
         null;
   end Record_Created;

   procedure Record_Moved (Destination, Source, Identity : String) is
   begin
      if Length (Current) = 0 then
         return;
      end if;
      Append_Record ("moved", Moved_Record_Header, Move_Record, Destination, Source, Identity);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         --  Called after the move: a journal failure must not turn a
         --  completed move into a failed filesystem operation.
         null;
   end Record_Moved;

   procedure Intend_Moved (Destination, Source, Identity : String) is
   begin
      if Length (Current) = 0 or else Identity = "" then
         return;
      end if;
      Append_Record ("moved-intent", Moved_Intent_Header, Move_Record, Destination, Source, Identity);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         --  Called before the move: recovery then finds this move only once
         --  it is recorded, as before intents were kept; the move goes ahead.
         null;
   end Intend_Moved;

   procedure Append_Record
     (Name, Header  : String;
      Shape         : Record_Shape;
      Destination   : String;
      Source        : String;
      Identity      : String;
      Tree_Revision : String := "")
   is
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Destination);
         String'Output (Stream, Source);
         String'Output (Stream, Identity);
         if Shape = Creation_Record then
            String'Output (Stream, Tree_Revision);
         end if;
      end Write;
   begin
      if Header'Length > Max_Record_Header_Length
        or else Destination'Length > Max_Record_Path_Length
        or else Source'Length > Max_Record_Path_Length
        or else Identity'Length > Max_Record_Token_Length
        or else (Shape = Creation_Record and then Tree_Revision'Length > Max_Record_Token_Length)
      then
         --  A developer trace: field=value pairs, no prose.
         Files.Diagnostics.Trace ("Files.Jobs.Context", "dropped=" & Name & ",reason=field_too_long");
         return;
      end if;
      Append_Journal_Record (Name, Header, Write'Access);
   end Append_Record;

   --  One journal: Name in Directory, under Header, of records of Shape. A
   --  source may be empty only in a Creation_Record (an archive or an
   --  extraction has none). A record out of shape ends the read there: the
   --  records before it are kept, as a crash mid-append tears only the last
   --  one, and nothing after it is trusted. A failed append cuts its torn
   --  record back off (Append_Journal_Record), so a later record never
   --  follows one. A journal whose header is wrong is not read at all. One
   --  the host says is not there is none; one that cannot be opened (or
   --  whose folder is refused) is read as none too, but traced, as a
   --  refused lookup is not an absent journal.
   procedure Read_Journal
     (Directory, Name, Header : String;
      Shape                   : Record_Shape;
      Entries                 : out Journal_Entry_Vectors.Vector)
   is
      Count : Natural := 0;
      Path : constant String := Hostkit.Fs.Join (Directory, Name);
      Input : aliased Files.Lease_Streams.Input_Stream;
      Size : Long_Long_Integer;
   begin
      Entries.Clear;
      if Valid_Record_Path (Directory)
        and then not Hostkit.Fs.Is_Link (Directory)
        and then Files.Fs_Primitives.Entry_Is_Absent (Path)
      then
         return;
      end if;
      if not Valid_Record_Path (Directory)
        or else Hostkit.Fs.Is_Link (Directory)
        or else not Files.Fs_Primitives.Directory_Exists (Directory)
        or else Files.Lease_Streams.Open (Path, Input) /=
          Hostkit.Lease_Files.Opened
      then
         Files.Diagnostics.Trace ("Files.Jobs.Context", "journal_refused=" & Path);
         return;
      end if;
      Size := Files.Lease_Streams.Size (Input);
      if Size < 0 or else Size > Long_Long_Integer (Max_Journal_Bytes)
      then
         Files.Lease_Streams.Release (Input);
         return; --  A journal past the limit, or of no readable size, is not read.
      end if;
      if Files.Bounded_Streams.Input_String
        (Input'Access, Max_Record_Header_Length) /= Header
      then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      while not Files.Lease_Streams.End_Of_Stream (Input) loop
         if Count = Max_Journal_Records then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         declare
            Destination : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Source      : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Path_Length);
            Identity    : constant String := Files.Bounded_Streams.Input_String
              (Input'Access, Max_Record_Token_Length);
            Revision    : constant String :=
              (if Shape = Creation_Record
               then Files.Bounded_Streams.Input_String (Input'Access, Max_Record_Token_Length)
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
      Files.Lease_Streams.Release (Input);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         Files.Lease_Streams.Release (Input);
   end Read_Journal;

   --  Add to Entries each intent the journal Intents (under Header) holds
   --  that Happened and Entries does not record yet, once, in the order
   --  named. Of several intents for one destination the latest that
   --  Happened counts: a publication names its entry again once inheriting
   --  its folder's access changed its revision (Intend_Created), and that
   --  later intent carries the revision the entry has now.
   procedure Add_Carried_Out
     (Entries                 : in out Journal_Entry_Vectors.Vector;
      Directory, Name, Header : String;
      Shape                   : Record_Shape;
      Happened                : not null access function (Item : Journal_Entry) return Boolean)
   is
      Intents : Journal_Entry_Vectors.Vector;
      --  Destinations recorded, or already given by a later intent.
      Taken   : Destination_Sets.Set;
   begin
      Read_Journal (Directory, Name, Header, Shape, Intents);
      if Intents.Is_Empty then
         return;
      end if;
      for Item of Entries loop
         Taken.Include (To_String (Item.Destination));
      end loop;
      declare
         Chosen : array (Intents.First_Index .. Intents.Last_Index) of Boolean := [others => False];
      begin
         for Index in reverse Chosen'Range loop
            if not Taken.Contains (To_String (Intents (Index).Destination)) and then Happened (Intents (Index)) then
               Taken.Include (To_String (Intents (Index).Destination));
               Chosen (Index) := True;
            end if;
         end loop;
         for Index in Chosen'Range loop
            if Chosen (Index) then
               Entries.Append (Intents (Index));
            end if;
         end loop;
      end;
   end Add_Carried_Out;

   function Read_Created (Directory : String) return Journal_Entry_Vectors.Vector is
      --  Published: what is at the destination is the entry staged.
      function Published (Item : Journal_Entry) return Boolean is
        (Files.File_Identities.Token (To_String (Item.Destination)) = To_String (Item.Identity));
   begin
      return Entries : Journal_Entry_Vectors.Vector do
         Read_Journal (Directory, "created", Created_Record_Header, Creation_Record, Entries);
         Add_Carried_Out
           (Entries, Directory, "created-intent", Created_Intent_Header, Creation_Record, Published'Access);
      end return;
   end Read_Created;

   function Read_Moved (Directory : String) return Journal_Entry_Vectors.Vector is
      --  Moved: the entry is at the destination, and its source gone for
      --  sure (a source the host will not answer for is not taken as moved).
      function Moved (Item : Journal_Entry) return Boolean is
        (Files.File_Identities.Token (To_String (Item.Destination)) = To_String (Item.Identity)
         and then Files.Fs_Primitives.Entry_Is_Absent (To_String (Item.Source)));
   begin
      return Entries : Journal_Entry_Vectors.Vector do
         Read_Journal (Directory, "moved", Moved_Record_Header, Move_Record, Entries);
         Add_Carried_Out (Entries, Directory, "moved-intent", Moved_Intent_Header, Move_Record, Moved'Access);
      end return;
   end Read_Moved;

   procedure Register_Stage_Internal
     (Path, Identity, Record_Directory : String)
   is
      Owner : constant String := Hostkit.Fs.Join (Path, Files.Protocol_Names.Stage_Owner_File);
      Owner_Directory : constant String := Stage_Owner_Directory;
      procedure Write
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, Files.Protocol_Names.Stage_Owner_Header);
         String'Output (Stream, Owner_Directory);
         String'Output (Stream, Identity);
      end Write;
   begin
      if Identity = ""
        or else not Valid_Record_Path (Path)
        or else not Valid_Record_Path (Record_Directory)
        or else not Valid_Record_Path (Owner_Directory)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Publish_Record (Owner, Write'Access);
      Write_Stage_Record (Record_Directory, Path, Identity);
   end Register_Stage_Internal;

   --  A work stage's owner record: the job directory and its identity.
   type Owner_Record is record
      Directory, Identity : Files.Types.UString;
   end record;

   procedure Read_Owner_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : out Owner_Record) is
   begin
      Value.Directory := To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Max_Record_Path_Length));
      Value.Identity := To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Max_Record_Token_Length));
   end Read_Owner_Body;

   function Owner_Is_Valid (Value : Owner_Record) return Boolean is
     (Length (Value.Identity) > 0
      and then Valid_Record_Path (To_String (Value.Directory))
      and then Nul_Free (To_String (Value.Identity)));

   function Read_Owner_Record is new Files.Lease_Streams.Read_Record
     (Item => Owner_Record, Read_Body => Read_Owner_Body, Is_Consistent => Owner_Is_Valid);

   procedure Read_Owner
     (Path : String;
      Directory, Identity : out Files.Types.UString;
      Valid : out Boolean)
   is
      Value : Owner_Record;
   begin
      Directory := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      Valid := False;
      Value := Read_Owner_Record
        (Hostkit.Fs.Join (Path, Files.Protocol_Names.Stage_Owner_File),
         Files.Protocol_Names.Stage_Owner_Header,
         Max_Stage_Metadata_Bytes);
      Directory := Value.Directory;
      Identity := Value.Identity;
      Valid := True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         Directory := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         Valid := False;
   end Read_Owner;

   function Owner_Matches
     (Path, Directory, Expected_Identity : String) return Boolean
   is
      Recorded_Directory, Recorded_Identity : Files.Types.UString;
      Valid : Boolean;
   begin
      Read_Owner (Path, Recorded_Directory, Recorded_Identity, Valid);
      return Valid
        and then To_String (Recorded_Directory) = Directory
        and then To_String (Recorded_Identity) = Expected_Identity;
   end Owner_Matches;

   function Discard_Stage (Path : String) return Boolean is
      Directory, Identity : Files.Types.UString;
      Owner_Valid : Boolean;
      Foreground : constant Boolean := Length (Current) = 0;
      Foreground_Index : Natural := 0;
      Record_Directory : Files.Types.UString;
      Removed : Boolean := False;

      procedure Release_Foreground is
      begin
         if not Foreground or else Foreground_Index = 0 then
            return;
         end if;
         if Removed then
            Remove_Record (To_String (Record_Directory));
         end if;
         Foreground_Paths.Delete (Foreground_Index);
         Foreground_Records.Delete (Foreground_Index);
         --  A stage that is gone by other means (removed from outside) is no
         --  longer waiting for its discard: forgotten here, or the cleanup
         --  below would never run again in this process.
         for Index in reverse Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
            if Files.Fs_Primitives.Entry_Is_Absent (To_String (Foreground_Paths (Index))) then
               Remove_Record (To_String (Foreground_Records (Index)));
               Foreground_Paths.Delete (Index);
               Foreground_Records.Delete (Index);
            end if;
         end loop;
         if Foreground_Paths.Is_Empty and then Files.Jobs.Process.Active (Foreground_Job) then
            Files.Jobs.Process.Clean_Stages (Foreground_Job);
            --  Failed records remain in the transport directory. Releasing the
            --  session launches the normal cleanup helper and retains it for
            --  retry instead of abandoning a foreground stage.
            Files.Jobs.Process.Reset (Foreground_Job);
         end if;
      end Release_Foreground;
   begin
      if Foreground then
         for Index in Foreground_Paths.First_Index .. Foreground_Paths.Last_Index loop
            if To_String (Foreground_Paths (Index)) = Path then
               Foreground_Index := Index;
               Record_Directory := Foreground_Records (Index);
               exit;
            end if;
         end loop;
         if Foreground_Index = 0 or else not Files.Jobs.Process.Active (Foreground_Job) then
            return False;
         end if;
      end if;
      if Files.Fs_Primitives.Entry_Is_Absent (Path) then
         Removed := True;
         Release_Foreground;
         return True;
      end if;
      Read_Owner (Path, Directory, Identity, Owner_Valid);
      if Owner_Valid
        and then To_String (Directory) =
          (if Foreground then Files.Jobs.Process.Path (Foreground_Job, "") else To_String (Current))
      then
         Removed := Files.Jobs.Storage.Delete_Staging_Entry (Path, To_String (Identity));
      end if;
      Release_Foreground;
      return Removed;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
         Release_Foreground;
         return False;
   end Discard_Stage;

   --  What reading a stage record's data came to: the staged path and the
   --  identity it was made with; a record to discard, as it can never become
   --  valid; or one to keep, as what stopped it may pass.
   type Record_Reading is (Record_Read, Record_Discarded, Record_Kept);

   --  Read the stage record in Record_Directory.
   --
   --  @param Record_Directory The record's folder.
   --  @param Discard_Unreadable Whether data that will not open now is
   --    discarded rather than kept for a retry.
   --  @param Path The staged path, when Record_Read.
   --  @param Expected Its identity at creation (empty when the record was
   --    written before it was known), when Record_Read.
   --  @param Reading What the reading came to.
   procedure Read_Stage_Record
     (Record_Directory   : String;
      Discard_Unreadable : Boolean;
      Path, Expected     : out Files.Types.UString;
      Reading            : out Record_Reading)
   is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Data : constant String := Hostkit.Fs.Join (Record_Directory, "data");
      Open_Result : Hostkit.Lease_Files.Open_Outcome;
   begin
      Path := Null_Unbounded_String;
      Expected := Null_Unbounded_String;
      Reading := Record_Discarded;
      --  No published data means creation stopped before the staging
      --  pathname could be created, so this empty reservation is disposable.
      if Files.Fs_Primitives.Entry_Is_Absent (Data) then
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
      if Hostkit.Fs.Is_Link (Data) or else not Files.Fs_Primitives.File_Exists (Data) then
         return;
      end if;
      Open_Result := Files.Lease_Streams.Open (Data, Input);
      if Open_Result /= Hostkit.Lease_Files.Opened then
         Files.Lease_Streams.Release (Input);
         --  Refused objects (including links and multiply-linked files)
         --  cannot become valid records. Other failures may be transient,
         --  so the bounded worker retains them for retry.
         if Open_Result /= Hostkit.Lease_Files.Refused and then not Discard_Unreadable then
            Reading := Record_Kept;
         end if;
         return;
      elsif Files.Lease_Streams.Size (Input) > Max_Stage_Metadata_Bytes then
         Files.Lease_Streams.Release (Input);
         return;
      end if;
      begin
         if Files.Bounded_Streams.Input_String (Input'Access, Max_Record_Header_Length) /= Stage_Record_Header then
            Files.Lease_Streams.Release (Input);
            return;
         end if;
         Path := To_Unbounded_String (Files.Bounded_Streams.Input_String (Input'Access, Max_Record_Path_Length));
         Expected := To_Unbounded_String (Files.Bounded_Streams.Input_String (Input'Access, Max_Record_Token_Length));
         if not Files.Lease_Streams.End_Of_Stream (Input) then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Files.Lease_Streams.Release (Input);
         Reading := Record_Read;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
            Files.Lease_Streams.Release (Input);
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
         Files.Lease_Streams.Release (Input);
         Reading := Record_Kept;
   end Read_Stage_Record;

   --  The identity a stage at Path was created with, from its atomically
   --  published owner marker, when Directory owns it; without trusting the
   --  identity now found at the pathname.
   --
   --  @param Path A staged path.
   --  @param Directory The transport that should own it.
   --  @return Its creation identity, or empty.
   function Owner_Identity (Path, Directory : String) return String is
      Recorded_Directory, Identity : Files.Types.UString;
      Valid : Boolean;
   begin
      Read_Owner (Path, Recorded_Directory, Identity, Valid);
      return (if Valid and then To_String (Recorded_Directory) = Directory then To_String (Identity) else "");
   end Owner_Identity;

   --  Whether Path is a private copy stage Directory made, still the entry it
   --  created: only such a stage is removed.
   --
   --  @param Path A staged path.
   --  @param Expected Its creation identity.
   --  @param Directory The transport that should own it.
   --  @return True when it may be removed.
   function Is_Own_Stage (Path, Expected, Directory : String) return Boolean is
      Name : constant String := Files.Types.Leaf_Of (Path);
   begin
      return Name'Length > Files.Protocol_Names.Work_Stage_Prefix'Length
        and then Ada.Strings.Fixed.Head (Name, Files.Protocol_Names.Work_Stage_Prefix'Length)
          = Files.Protocol_Names.Work_Stage_Prefix
        and then Expected /= ""
        and then not Hostkit.Fs.Is_Link (Path)
        and then Files.File_Identities.Token (Path) = Expected
        and then Owner_Matches (Path, Directory, Expected);
   end Is_Own_Stage;

   procedure Clean_Stages
     (Directory          : String;
      Owner              : Files.Jobs.Transports.Lease;
      Discard_Unreadable : Boolean := False)
   is
      Stages : constant String := Hostkit.Fs.Join (Directory, Files.Protocol_Names.Stages_Directory);
      Records : Files.Types.String_Vectors.Vector;

      --  The stage folders, a link to one included, as the search listed them.
      procedure Collect (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         Prefix : constant String := "stage-";
      begin
         if Name'Length >= Prefix'Length
           and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
           and then Files.Fs_Primitives.Directory_Exists (Hostkit.Fs.Join (Stages, Name))
         then
            Records.Append (To_Unbounded_String (Hostkit.Fs.Join (Stages, Name)));
         end if;
      end Collect;

      procedure Clean_Record (Record_Directory : String) is
         Path, Expected : Files.Types.UString;
         Reading        : Record_Reading;
      begin
         if Hostkit.Fs.Is_Link (Record_Directory)
           or else not Files.Fs_Primitives.Directory_Exists (Record_Directory)
         then
            return;
         end if;
         Read_Stage_Record (Record_Directory, Discard_Unreadable, Path, Expected, Reading);
         case Reading is
            when Record_Kept =>
               return;
            when Record_Discarded =>
               Remove_Record (Record_Directory);
               return;
            when Record_Read =>
               null;
         end case;
         if not Valid_Record_Path (To_String (Path))
           or else not Nul_Free (To_String (Expected))
           or else Files.Fs_Primitives.Entry_Is_Absent (To_String (Path))
         then
            Remove_Record (Record_Directory);
            return;
         end if;
         if Length (Expected) = 0 then
            --  The write-ahead record may precede finalization.
            Expected := To_Unbounded_String (Owner_Identity (To_String (Path), Directory));
         end if;
         if Is_Own_Stage (To_String (Path), To_String (Expected), Directory)
           and then Files.Jobs.Storage.Delete_Staging_Entry (To_String (Path), To_String (Expected))
         then
            Remove_Record (Record_Directory);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Jobs.Context");
            --  Keep only this record for retry; damage cannot hide later
            --  independent records as it could in the append-only journal.
      end Clean_Record;
   begin
      if not Files.Jobs.Transports.Holds (Owner, Directory) then
         return;
      end if;
      if Hostkit.Fs.Is_Link (Stages) or else not Files.Fs_Primitives.Directory_Exists (Stages) then
         return;
      end if;
      Files.Fs_Primitives.For_Each_Name (Stages, Collect'Access);
      for Record_Directory of Records loop
         Clean_Record (To_String (Record_Directory));
      end loop;
      begin
         Files.Fs_Primitives.Delete_Directory (Stages);
      exception
         when Ada.Directories.Use_Error => null;
      end;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Jobs.Context");
   end Clean_Stages;
end Files.Jobs.Context;
