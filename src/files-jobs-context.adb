with Files.Text_Basics;
with Files.Protocol_Names;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files.IO.Record_Fields;
with Files.Jobs.Storage;
with Files.IO.Fs_Primitives;
with Files.IO.Durable_Writes;
with Files.IO.Private_Directories;
with Files.Jobs.Process;
with Files.IO.Durability;
with Hostkit.Durability;
with Hostkit.Fs;
with Hostkit.Lease_Files;
with Files.File_Identities;
with Files.IO.Lease_Streams;
with Files.Path_Checks;
with Ada.Real_Time;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Files.Name_Parts;

package body Files.Jobs.Context is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Files.IO.Private_Directories.Create_Result;
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
   Max_Record_Header_Length : constant := Files.IO.Record_Fields.Max_Header_Length;
   Max_Record_Path_Length : constant := Files.IO.Record_Fields.Max_Path_Length;
   Max_Record_Token_Length : constant := Files.IO.Record_Fields.Max_Token_Length;
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
      if not Files.IO.Durable_Writes.Published (Files.IO.Durable_Writes.Write_And_Publish (Target, Write_Record)) then
         raise Ada.Directories.Use_Error;
      end if;
   end Publish_Record;

   procedure Append_Journal_Record
     (Name, Header : String;
      Write_Record : not null access procedure
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
   is separate;

   --  Flush a journal just appended to, then its folder. The record is
   --  written either way, so a failed flush does not fail the append: the
   --  record holds unless the machine stops before the device catches up.
   --  It is traced, for a dying disk shows here first.
   procedure Sync_Journal (Path : String) is
      File_Sync : constant Hostkit.Durability.Outcome := Files.IO.Durability.Sync_File (Path);
   begin
      if File_Sync = Hostkit.Durability.Failed then
         Files.Diagnostics.Trace ("Files.Jobs.Context", "journal_sync_failed=" & Path);
      elsif File_Sync = Hostkit.Durability.Synced
        and then Files.IO.Durability.Sync_Directory (Files.IO.Fs_Primitives.Parent_Directory (Path)) =
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
        and then Files.IO.Fs_Primitives.Directory_Exists (Record_Directory)
      then
         Files.IO.Fs_Primitives.Delete_Tree_If_Present (Record_Directory);
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
      if Files.IO.Private_Directories.Try_Create (Stages) =
        Files.IO.Private_Directories.Collision
        and then (Hostkit.Fs.Is_Link (Stages) or else not Files.IO.Fs_Primitives.Directory_Exists (Stages))
      then
         raise Ada.Directories.Use_Error;
      end if;
      declare
         Record_Directory : constant String := Files.IO.Private_Directories.Create_Numbered (Stages, "stage-");
      begin
         if Record_Directory = "" then
            raise Ada.Directories.Use_Error;
         end if;
         --  Publish the intended pathname before creating it. A crash can
         --  therefore leave an unfinished record, never an undiscoverable
         --  staging directory.
         Write_Stage_Record (Record_Directory, Path, "");
         return Record_Directory;
      exception
         when others =>
            if Record_Directory /= "" then
               Remove_Record (Record_Directory);
            end if;
            raise;
      end;
   end Begin_Stage_Record;

   function Create_Stage (Parent : String) return String is separate;

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
   is separate;

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
         and then Files.IO.Fs_Primitives.Entry_Is_Absent (To_String (Item.Source)));
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
      Value.Directory := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Record_Path_Length));
      Value.Identity := To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Max_Record_Token_Length));
   end Read_Owner_Body;

   function Owner_Is_Valid (Value : Owner_Record) return Boolean is
     (Length (Value.Identity) > 0
      and then Valid_Record_Path (To_String (Value.Directory))
      and then Nul_Free (To_String (Value.Identity)));

   function Read_Owner_Record is new Files.IO.Lease_Streams.Read_Record
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

   function Discard_Stage (Path : String) return Boolean is separate;

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
   is separate;

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
      Name : constant String := Files.Name_Parts.Leaf_Of (Path);
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
   is separate;
end Files.Jobs.Context;
