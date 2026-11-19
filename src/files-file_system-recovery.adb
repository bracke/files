with Files.Types;
with Files.Fs_Primitives;
with Files.Timing;
with Files.Protocol_Names;
with Files.File_System.Support;
with Files.Diagnostics;
with Files.File_Identities;
with Files.Io_Errors;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Finalization;
with Ada.Task_Identification;
with Ada.Directories;
with Ada.Streams;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Files.Durability;
with Hostkit.Durability;
with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Lease_Files;
with Hostkit.Locks;
with Hostkit.Metadata;
with Files.Bounded_Streams;
with Files.Exclusive_Streams;
with Files.Lease_Streams;
with Files.Private_Directories;
with Files.Path_Checks;

package body Files.File_System.Recovery is

   --  Remove a copied move's source atomically before recursive cleanup.
   --  @param Path Source whose complete destination copy has been published.
   --  @param Expected Identity and revision snapshot captured before copying.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Set_Aside Set when the source had changed since the copy and
   --    could not be put back: it is then only in its recovery stage, still
   --    registered, and the caller must keep its copy.
   --  @param Cancel What stops its checks: the job's cancellation unless
   --    given another, null for none.
   --  @return Failure leaves the source at its pathname unless Set_Aside;
   --    success vacates its pathname.
   function Remove_Move_Source
     (Path         : String;
      Expected     : Support.Source_Snapshot;
      Fallback_Key : String;
      Set_Aside    : out Boolean;
      Cancel       : Cancellation_Check := Job_Cancelled) return Mutation_Result;

   use Ada.Strings.Unbounded;
   use Files.File_System.Support;
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Files.Private_Directories.Create_Result;
   use type Hostkit.Durability.Outcome;
   use type Hostkit.Lease_Files.Open_Outcome;

   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   Owner_Name : constant String := Files.Protocol_Names.Recovery_Owner;
   --  Written, synced, in the stage before Restore moves the payload out:
   --  only a stage carrying it and no payload is a restore that stopped.
   Vacated_Marker : constant String := Files.Protocol_Names.Recovery_Vacated;
   --  Written, synced, in the stage before Release moves the payload into
   --  release/: only a stage carrying it is a release that may have stopped.
   Releasing_Marker : constant String := Files.Protocol_Names.Recovery_Releasing;
   --  What a marker lease holds: written once, durably, so the name is a
   --  file with content rather than an empty create a crash could lose.
   Marker_Content : constant Ada.Streams.Stream_Element_Array (1 .. 8) := [others => 16#4D#];
   Owner_Magic : constant String := "files-recovery-v1";
   Registry_Magic : constant String := "files-recovery-registry-v1";
   Max_Header_Length : constant := Files.Bounded_Streams.Max_Header_Length;
   Max_Path_Length : constant := Files.Bounded_Streams.Max_Path_Length;
   Max_Identity_Length : constant := Files.Bounded_Streams.Max_Token_Length;
   Max_Record_Bytes : constant :=
     Max_Header_Length + Max_Path_Length + Max_Identity_Length + 3 * 16;

   function Record_Is_Regular
     (Path : String; Maximum : Natural := Max_Record_Bytes) return Boolean
   is
   begin
      return not Hostkit.Fs.Is_Link (Path)
        and then Files.Fs_Primitives.File_Exists (Path)
        and then Files.Fs_Primitives.Size (Path) <= Ada.Directories.File_Size (Maximum);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return False;
   end Record_Is_Regular;

   function Valid_Absolute_Path (Path : String) return Boolean is
     (Files.Path_Checks.Valid_Absolute_Path (Path));

   procedure Write_Bounded
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Maximum : Natural) renames Files.Bounded_Streams.Output_String;

   function Registry_Root (Create : Boolean) return String is
      Data : constant String := Support.Application_Data_Directory;
      App  : constant String := Support.Files_Data_Directory;
      Root : constant String :=
        (if App = "" then "" else Hostkit.Fs.Join (App, Files.Protocol_Names.Recovery_Index_Folder));

      procedure Ensure_Directory (Path : String; Parents : Boolean := False) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            raise Ada.Directories.Use_Error;
         elsif not Files.Fs_Primitives.Entry_Is_Absent (Path) then
            if not Files.Fs_Primitives.Directory_Exists (Path) then
               raise Ada.Directories.Use_Error;
            end if;
         elsif Parents then
            Files.Fs_Primitives.Create_Path (Path);
         else
            Files.Private_Directories.Create (Path);
         end if;
      end Ensure_Directory;
   begin
      if Root = "" then
         return "";
      end if;
      if Create then
         Ensure_Directory (Data, Parents => True);
         Ensure_Directory (App);
         Ensure_Directory (Root);
      elsif Hostkit.Fs.Is_Link (Root) or else not Files.Fs_Primitives.Directory_Exists (Root) then
         return "";
      end if;
      return Root;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return "";
   end Registry_Root;

   --  What an owner or registry record holds after its header.
   type Path_Record is record
      Path, Identity : UString;
   end record;

   procedure Read_Path_Record_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : out Path_Record) is
   begin
      Value.Path := To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Max_Path_Length));
      Value.Identity := To_Unbounded_String (Files.Bounded_Streams.Input_String (Stream, Max_Identity_Length));
   end Read_Path_Record_Body;

   function Records_Absolute_Path (Value : Path_Record) return Boolean is
     (Valid_Absolute_Path (To_String (Value.Path)));

   function Read_Path_Record_File is new Files.Lease_Streams.Read_Record
     (Item => Path_Record, Read_Body => Read_Path_Record_Body, Is_Consistent => Records_Absolute_Path);

   --  Read a record file -- its magic, a path and an identity token -- held
   --  as a lease while it is read: a plain file no larger than
   --  Max_Record_Bytes, with nothing after the identity. Raises when it
   --  cannot be read, carries another magic, is malformed or records no
   --  absolute path; the caller's handler clears Path and Identity then.
   --
   --  @param Record_Path The record file.
   --  @param Magic The header the record must carry.
   --  @param Path The path it records.
   --  @param Identity The identity token it records, possibly empty.
   --  @return False when Record_Path is not a plain file; True once read.
   function Read_Path_Record
     (Record_Path, Magic : String; Path, Identity : out UString) return Boolean
   is
      Value : Path_Record;
   begin
      Path := Null_Unbounded_String;
      Identity := Null_Unbounded_String;
      if not Record_Is_Regular (Record_Path) then
         return False;
      end if;
      Value := Read_Path_Record_File (Record_Path, Magic, Max_Record_Bytes);
      Path := Value.Path;
      Identity := Value.Identity;
      return True;
   end Read_Path_Record;

   function Read_Owner
     (Stage : String; Original, Identity : out UString) return Boolean
   is
   begin
      return Read_Path_Record (Hostkit.Fs.Join (Stage, Owner_Name), Owner_Magic, Original, Identity)
        and then
          (Length (Identity) = 0
           or else Files.File_Identities.Token (Stage) = To_String (Identity));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Original := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         return False;
   end Read_Owner;

   procedure Write_Owner (Stage, Original : String) is
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      if not Valid_Absolute_Path (Original) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Exclusive_Streams.Create (File, Hostkit.Fs.Join (Stage, Owner_Name));
      Write_Bounded
        (File'Access, Owner_Magic, Max_Header_Length);
      Write_Bounded
        (File'Access, Original, Max_Path_Length);
      Write_Bounded
        (File'Access, Files.File_Identities.Token (Stage), Max_Identity_Length);
      Files.Exclusive_Streams.Close (File);
      if Files.Durability.Sync_File (Hostkit.Fs.Join (Stage, Owner_Name)) /=
        Hostkit.Durability.Synced
      then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others => Files.Exclusive_Streams.Close_Safely (File); raise;
   end Write_Owner;

   --  Whether Stage carries the marker Name (Vacated_Marker or
   --  Releasing_Marker) as a plain file of its own.
   function Has_Marker (Stage, Name : String) return Boolean is
     (Record_Is_Regular (Hostkit.Fs.Join (Stage, Name)));

   --  A restore or release marks its stage before the payload leaves it
   --  and holds the marker as a lease for as long as it works there, so a
   --  sweep (in this or another process) can tell a stage whose payload
   --  left on purpose from one Preserve is still filling -- and a stopped
   --  operation, whose lease went with its process, from a live one.
   --
   --  Take the marker Name in Stage for this operation: create it, durable,
   --  or claim one a stopped operation left behind. False when another
   --  holder has it: a live operation owns the stage. Raises when the
   --  marker can be neither made nor claimed.
   function Hold_Marker
     (Stage, Name : String;
      Item        : in out Hostkit.Lease_Files.Lease)
      return Boolean
   is separate;

   --  Claim a present marker for a sweep: True when it is held now, by
   --  this caller alone, so no live operation owns it. A missing marker or
   --  one another holder has is not claimed.
   function Claim_Marker
     (Stage, Name : String;
      Item        : in out Hostkit.Lease_Files.Lease)
      return Boolean
   is
   begin
      return Has_Marker (Stage, Name)
        and then Hostkit.Lease_Files.Open
          (Hostkit.Fs.Join (Stage, Name), Hostkit.Lease_Files.Exclusive, True, Item) =
            Hostkit.Lease_Files.Opened;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Hostkit.Lease_Files.Release (Item);
         return False;
   end Claim_Marker;

   --  Let go of a held marker. With Remove, the payload is back in Stage
   --  (the stage is whole again) and the marker goes too; otherwise it stays
   --  for the stage's cleanup. Best effort: a marker left beside a present
   --  payload does nothing, as every sweep first requires the payload gone.
   --  The lease goes first: Windows refuses to delete a file held open.
   procedure Let_Go_Marker
     (Stage, Name : String;
      Item        : in out Hostkit.Lease_Files.Lease;
      Remove      : Boolean)
   is
   begin
      Hostkit.Lease_Files.Release (Item);
      if Remove and then Has_Marker (Stage, Name) then
         Files.Fs_Primitives.Delete_File (Hostkit.Fs.Join (Stage, Name));
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
   end Let_Go_Marker;

   --  Remove Stage, whose payload is gone, while Item holds one of its
   --  markers. POSIX removes a held file, so the lease is kept until the
   --  stage is gone; Windows refuses that, so the lease goes first. Another
   --  claimer that slips into that gap can only remove the same stage.
   procedure Remove_Stage_Holding
     (Stage : String;
      Item  : in out Hostkit.Lease_Files.Lease)
   is
   begin
      if Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows) then
         Hostkit.Lease_Files.Release (Item);
      end if;
      Delete_Owned_Tree (Stage);
      Hostkit.Lease_Files.Release (Item);
   exception
      when others => Hostkit.Lease_Files.Release (Item); raise;
   end Remove_Stage_Holding;

   function Contains_Only_Owned_Entries (Stage : String) return Boolean is
      Only_Owned : Boolean := True;

      procedure Check (Name : String; Stop : in out Boolean) is
      begin
         if Name not in "payload" | "original" | "mode" | Vacated_Marker | Releasing_Marker | Owner_Name then
            Only_Owned := False;
            Stop := True;
         end if;
      end Check;
   begin
      Files.Fs_Primitives.For_Each_Name (Stage, Check'Access);
      return Only_Owned;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
         return False;
   end Contains_Only_Owned_Entries;

   function Read_Registry_Record
     (Directory : String; Payload, Identity : out UString) return Boolean
   is
   begin
      if Hostkit.Fs.Is_Link (Directory) or else not Files.Fs_Primitives.Directory_Exists (Directory) then
         Payload := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         return False;
      end if;
      return Read_Path_Record (Hostkit.Fs.Join (Directory, "record"), Registry_Magic, Payload, Identity);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Payload := Null_Unbounded_String;
         Identity := Null_Unbounded_String;
         return False;
   end Read_Registry_Record;

   --  Every change to the registry happens under one advisory lock on a file
   --  in it, across processes and tasks. Without it, a process that judged a
   --  slot stale and went to delete it could delete the fresh slot another
   --  process had reclaimed under the same name in between -- whose record
   --  then failed to write, and whose Undo failed with it.
   --
   --  Held per task and reentrantly: a sweep that finishes a stage goes on
   --  to unregister it, and a second lock on the file from the same process
   --  would wait for itself.
   protected Registry_Owner is
      --  @return Whether Task holds the lock.
      function Holds (Task_Id : Ada.Task_Identification.Task_Id) return Boolean;
      procedure Claim (Task_Id : Ada.Task_Identification.Task_Id);
      procedure Clear;
   private
      Owner : Ada.Task_Identification.Task_Id := Ada.Task_Identification.Null_Task_Id;
   end Registry_Owner;

   protected body Registry_Owner is
      function Holds (Task_Id : Ada.Task_Identification.Task_Id) return Boolean is
        (Ada.Task_Identification."=" (Owner, Task_Id));

      procedure Claim (Task_Id : Ada.Task_Identification.Task_Id) is
      begin
         Owner := Task_Id;
      end Claim;

      procedure Clear is
      begin
         Owner := Ada.Task_Identification.Null_Task_Id;
      end Clear;
   end Registry_Owner;

   --  The lock while it lives; an inner hold in the same task does nothing.
   type Registry_Hold is new Ada.Finalization.Limited_Controlled with record
      Lock  : Hostkit.Locks.Lock;
      Outer : Boolean := False;
   end record;

   overriding procedure Finalize (Hold : in out Registry_Hold);

   overriding procedure Finalize (Hold : in out Registry_Hold) is
   begin
      if Hold.Outer then
         Hold.Outer := False;
         Registry_Owner.Clear;
         Hostkit.Locks.Release (Hold.Lock);
      end if;
   end Finalize;

   --  Take the registry lock under Root for this task, waiting for any
   --  other holder. A host or volume without advisory locks (or one that
   --  refuses this lock file) goes on unguarded, as every registry change did
   --  before the lock: the outcome is traced, and nothing is claimed, so no
   --  later hold in this task believes it is guarded and nothing is released.
   --
   --  Held only around reading and changing the registry itself, never
   --  around the work a record leads to (a payload's move, a stage's
   --  removal): Preserve registers from the window, which must not wait out a
   --  sweep's trash move. The stage markers serialise that work instead.
   procedure Hold_Registry (Root : String; Hold : in out Registry_Hold) is
      use type Hostkit.Locks.Lock_Outcome;
   begin
      if Root = "" or else Registry_Owner.Holds (Ada.Task_Identification.Current_Task) then
         return;
      end if;
      declare
         Outcome : constant Hostkit.Locks.Lock_Outcome := Hostkit.Locks.Acquire
           (Hostkit.Fs.Join (Root, Files.Protocol_Names.Recovery_Registry_Lock),
            Hostkit.Locks.Lock_Exclusive, Wait => True, Item => Hold.Lock);
      begin
         if Outcome /= Hostkit.Locks.Lock_Ok then
            Files.Diagnostics.Trace
              ("Files.File_System.Recovery", "registry_lock=" & Hostkit.Locks.Lock_Outcome'Image (Outcome));
            return;
         end if;
      end;
      Registry_Owner.Claim (Ada.Task_Identification.Current_Task);
      Hold.Outer := True;
   end Hold_Registry;

   procedure Delete_Registry_Record (Directory : String) is separate;

   --  A record whose stage directory is gone describes nothing recoverable.
   --  Preserve creates the stage before registering, so a live record always
   --  has one; an unreadable (possibly half-written) record is never stale.
   function Is_Stale_Record (Directory : String) return Boolean is
      Payload, Identity : UString;
   begin
      if not Read_Registry_Record (Directory, Payload, Identity) then
         return False;
      end if;
      declare
         Stage : constant String :=
           Files.Fs_Primitives.Parent_Directory (To_String (Payload));
      begin
         return Files.Fs_Primitives.Entry_Is_Absent (Stage);
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return False;
   end Is_Stale_Record;

   function Register (Payload : String) return String is separate;

   procedure Unregister (Payload : String) is separate;

   --  Release moves the payload into release/<its original name> before
   --  trashing it. Stopped between the two (a crash, or a failed trash whose
   --  move back failed too), the stage holds no payload, which nothing would
   --  recognize again: move the held entry back so the stage is whole. The
   --  caller holds the stage's release marker.
   --  @return True when the payload is back in its stage.
   function Resume_Held_Release (Path : String) return Boolean is separate;

   --  Resume a stopped release (see Resume_Held_Release) found by anyone
   --  but the release itself. Only a stage whose release marker this can
   --  claim is touched: without the marker the holder is nothing Release
   --  made, and a marker another holder has is a release still running.
   procedure Resume_Interrupted_Release (Path : String) is
      Stage  : constant String := Files.Fs_Primitives.Parent_Directory (Path);
      Marker : Hostkit.Lease_Files.Lease;
   begin
      --  refusal-safe: a refused payload goes on to the claimed resume, which only moves no-replace
      if Files.Fs_Primitives.Entry_Exists (Path)
        or else not Claim_Marker (Stage, Releasing_Marker, Marker)
      then
         return;
      end if;
      Let_Go_Marker (Stage, Releasing_Marker, Marker, Remove => Resume_Held_Release (Path));
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Hostkit.Lease_Files.Release (Marker);
   end Resume_Interrupted_Release;

   --  A release or restore that moved the payload out (to the trash, back
   --  to its original, or beside it) and stopped before it removed the
   --  stage: only the stage is left, and finishing means removing it.
   --  Retrying on the missing payload would fail for good and keep the stage
   --  forever. The marker the operation wrote before the payload left is
   --  what tells it apart from a stage Preserve has registered but not yet
   --  filled, which must be left alone. A caller acting on this holds the
   --  marker (see Hold_Marker, Claim_Marker), so the operation is not live.
   function Only_Stage_Left (Path : String) return Boolean is
      Stage    : constant String := Files.Fs_Primitives.Parent_Directory (Path);
      Holder   : constant String := Hostkit.Fs.Join (Stage, "release");
      Original : UString;
      Identity : UString;
   begin
      --  Absent for sure, not merely unanswered: a refused lookup of the
      --  payload must never let the stage, original inside, be removed.
      return Files.Fs_Primitives.Entry_Is_Absent (Path)
        and then Files.Fs_Primitives.Entry_Is_Absent (Holder)
        and then Files.Types.Leaf_Of (Path) = "payload"
        and then (Has_Marker (Stage, Vacated_Marker) or else Has_Marker (Stage, Releasing_Marker))
        and then Read_Owner (Stage, Original, Identity)
        and then Contains_Only_Owned_Entries (Stage);
   end Only_Stage_Left;

   --  Remove the stage of Payload, which a restore or release emptied and
   --  stopped in, once every marker on it is claimed: one another holder
   --  has belongs to an operation still running, which finishes itself.
   --  @return True when the markers were claimed (the stage may still have
   --    refused to go).
   function Finish_Stopped_Stage (Payload : String) return Boolean is
      Stage     : constant String := Files.Fs_Primitives.Parent_Directory (Payload);
      Vacated   : Hostkit.Lease_Files.Lease;
      Releasing : Hostkit.Lease_Files.Lease;
      Claimed   : Boolean;
   begin
      Claimed :=
        (not Has_Marker (Stage, Vacated_Marker) or else Claim_Marker (Stage, Vacated_Marker, Vacated))
        and then (not Has_Marker (Stage, Releasing_Marker)
                  or else Claim_Marker (Stage, Releasing_Marker, Releasing));
      if Claimed and then Only_Stage_Left (Payload) then
         --  Remove_Stage_Holding manages one lease; the other can go now:
         --  no new restore or release starts on a stage without its payload.
         Hostkit.Lease_Files.Release (Vacated);
         Remove_Stage_Holding (Stage, Releasing);
      end if;
      Hostkit.Lease_Files.Release (Vacated);
      Hostkit.Lease_Files.Release (Releasing);
      return Claimed;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Hostkit.Lease_Files.Release (Vacated);
         Hostkit.Lease_Files.Release (Releasing);
         return False;
   end Finish_Stopped_Stage;

   --  Whether the stage of Payload was registered and made by a Preserve
   --  that stopped before its original moved in, longer ago than
   --  Unfilled_Stage_Grace: no payload (gone for sure), no release holder,
   --  no restore or release marker, nothing but what Preserve writes, and an
   --  owner record older than the grace -- so no Preserve is filling it now.
   function Abandoned_Unfilled (Payload : String) return Boolean is
      Stage    : constant String := Files.Fs_Primitives.Parent_Directory (Payload);
      Owner    : constant String := Hostkit.Fs.Join (Stage, Owner_Name);
      Original : UString;
      Identity : UString;
   begin
      return Files.Types.Leaf_Of (Payload) = "payload"
        and then Files.Fs_Primitives.Entry_Is_Absent (Payload)
        and then Files.Fs_Primitives.Entry_Is_Absent (Hostkit.Fs.Join (Stage, "release"))
        and then not Has_Marker (Stage, Vacated_Marker)
        and then not Has_Marker (Stage, Releasing_Marker)
        and then Read_Owner (Stage, Original, Identity)
        and then Contains_Only_Owned_Entries (Stage)
        and then Files.Timing.Elapsed
          (Now      => Ada.Calendar.Clock,
           Since    => Hostkit.Fs.Modification_Time_Of (Owner, Follow_Links => False),
           Interval => Unfilled_Stage_Grace);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return False;
   end Abandoned_Unfilled;

   --  Remove an abandoned, unfilled stage (Abandoned_Unfilled), holding its
   --  restore marker meanwhile so nothing else starts on it.
   --  @return True when the stage was claimed (it may still have refused to go).
   function Remove_Abandoned_Stage (Payload : String) return Boolean is
      Stage  : constant String := Files.Fs_Primitives.Parent_Directory (Payload);
      Marker : Hostkit.Lease_Files.Lease;
   begin
      if not Hold_Marker (Stage, Vacated_Marker, Marker) then
         return False;
      end if;
      Remove_Stage_Holding (Stage, Marker);
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Hostkit.Lease_Files.Release (Marker);
         return False;
   end Remove_Abandoned_Stage;

   function Vacate
     (Path  : String;
      Leave : not null access function return Boolean;
      Ran   : out Boolean)
      return Boolean
   is separate;

   function Release
     (Path     : String;
      To_Trash : not null access function (Path, Original : String) return Mutation_Result)
      return Mutation_Result
   is separate;

   function Remove_Move_Source
     (Path         : String;
      Expected     : Support.Source_Snapshot;
      Fallback_Key : String;
      Set_Aside    : out Boolean;
      Cancel       : Cancellation_Check := Job_Cancelled) return Mutation_Result
   is separate;

   function Move_By_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := Job_Cancelled;
      Batch               : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session;
      If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
      After_Copy          : Copy_Hook := null;
      Expected_Identity   : String := "")
      return Mutation_Result
   is separate;

   function Recognizes (Path : String) return Boolean is
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Path);
      Original, Identity : UString;
   begin
      return Files.Types.Leaf_Of (Path) = "payload"
        and then Starts_With (Files.Types.Leaf_Of (Parent), Files.Protocol_Names.Recovery_Stage_Prefix)
        and then not Hostkit.Fs.Is_Link (Parent)
        and then Files.Fs_Primitives.Directory_Exists (Parent)
        --  refusal-safe: a refused payload is not recognized, so nothing acts on it
        and then Files.Fs_Primitives.Entry_Exists (Path)
        and then Read_Owner (Parent, Original, Identity);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return False;
   end Recognizes;

   function Discard (Path : String) return Mutation_Result is
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Path);
   begin
      Resume_Interrupted_Release (Path);
      if not Recognizes (Path) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      if not Contains_Only_Owned_Entries (Parent) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      Delete_Owned_Tree (Parent);
      if not Files.Fs_Primitives.Entry_Is_Absent (Parent) then
         raise Ada.Directories.Use_Error;
      end if;
      Unregister (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Discard;

   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result is separate;

   function Original_Path (Path : String) return String is separate;

   --  Whether the stage holding Payload is still the one its record named.
   function Stage_Matches (Payload, Expected : String) return Boolean is
     (Expected = ""
      or else Files.File_Identities.Token (Files.Fs_Primitives.Parent_Directory (Payload)) = Expected);

   procedure Sweep_Registry is separate;

   function Registered_Payloads return Files.Types.String_Vectors.Vector is separate;

   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result
   is separate;
end Files.File_System.Recovery;
