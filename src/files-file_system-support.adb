with Files.IO.Fs_Primitives;
with Files.Protocol_Names;
with Interfaces;
with Ada.Streams;
with Files.Environment;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;
with Files.Jobs.Context;
with Hostkit.Directory_Write_Access;
with Files.File_Identities;
with Files.IO.Errors;
with CryptoLib.Hashes;
with Files.File_System.Digests;

with Files.IO.Durability;
with Hostkit.Durability;
with Hostkit.Metadata;
with Hostkit.Regular_Files;
with Files.Text_Basics;

package body Files.File_System.Support is

   --  The most entries one directory may list before it counts as hostile.
   Max_Directory_Entries : constant := 1_000_000;
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Move_Outcome;
   use type Interfaces.Unsigned_64;

   function Sync_Copy
     (Source, Destination : String;
      Scope               : Sync_Scope := Files_And_Folders) return Boolean is
      use type Hostkit.Durability.Outcome;
      Synced : Boolean := True;

      procedure Sync (From, To : String) is
         procedure Visit (Name : String) is
         begin
            if Synced then
               Sync (Hostkit.Fs.Join (From, Name), Hostkit.Fs.Join (To, Name));
            end if;
         end Visit;
      begin
         --  Something the source gained after it was copied is not in the
         --  copy: the move's own check of the source refuses it next.
         if Hostkit.Fs.Is_Link (To) or else Files.IO.Fs_Primitives.Entry_Is_Absent (To) then
            return;
         --  refusal-safe: a part of the copy that cannot be looked at
         --  cannot be synced either, and the copy is not durable.
         elsif not Files.IO.Fs_Primitives.Entry_Exists (To) then
            Synced := False;
            return;
         elsif Files.IO.Fs_Primitives.Kind (To) = Ada.Directories.Directory then
            if not Hostkit.Fs.Is_Link (From) then
               For_Each_Entry (From, Visit'Access);
            end if;
            Synced := Synced
              and then Files.IO.Durability.Sync_Directory (To) /= Hostkit.Durability.Failed;
         elsif Scope = Files_And_Folders and then Files.IO.Fs_Primitives.Kind (To) = Ada.Directories.Ordinary_File then
            Synced := Files.IO.Durability.Sync_File (To) /= Hostkit.Durability.Failed;
         end if;
      end Sync;
      procedure Sync_Root is
      begin
         Sync (Source, Destination);
      end Sync_Root;
   begin
      --  As deep as the copy went (1024 levels): on a stack that holds it.
      On_Large_Stack (Sync_Root'Access);
      return Synced
        and then Files.IO.Durability.Sync_Directory (Files.IO.Fs_Primitives.Parent_Directory (Destination)) /=
          Hostkit.Durability.Failed;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
         return False;
   end Sync_Copy;

   procedure For_Each_Entry
     (Path : String; Visit : not null access procedure (Name : String))
   is
      --  Memory is bounded by the name bytes; the entry cap only stops a
      --  pathological directory. At 100_000 an ordinary large folder (a
      --  maildir, a cache, a dataset) could not be opened, copied or deleted.
      Max_Entries : constant Natural := Max_Directory_Entries;
      Max_Name_Bytes : constant Natural := 64 * 1024 * 1024;
      Names : Files.Types.String_Vectors.Vector;
      Name_Bytes : Natural := 0;

      procedure Collect (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
      begin
         if Natural (Names.Length) >= Max_Entries or else Name'Length > Max_Name_Bytes - Name_Bytes then
            raise Ada.Directories.Use_Error;
         end if;
         Names.Append (To_Unbounded_String (Name));
         Name_Bytes := Name_Bytes + Name'Length;
      end Collect;
   begin
      Files.IO.Fs_Primitives.For_Each_Name (Path, Collect'Access);
      --  Recursion retains neither a large buffer nor an open directory.
      for Name of Names loop
         Visit (To_String (Name));
      end loop;
   end For_Each_Entry;

   function Create_Stage (Parent : String) return String renames Files.Jobs.Context.Create_Stage;

   overriding function "=" (Left, Right : Source_Snapshot) return Boolean is
      use type Files.Types.String_Vectors.Vector;
   begin
      return Left.Root_Revision = Right.Root_Revision and then Left.Entries = Right.Entries;
   end "=";

   function Same_Shape (Left, Right : Source_Snapshot) return Boolean is
      use type Files.Types.String_Vectors.Vector;
   begin
      return Left.Root_Revision = Right.Root_Revision and then Left.Shapes = Right.Shapes;
   end Same_Shape;

   --  Work on a task of its own whose stack holds a tree walk's 1024 levels
   --  (about 1-2 KB each): the caller's may hold far fewer -- Windows gives
   --  the main thread 1 MiB -- and the recursion would overflow it long before
   --  the walk's depth cap refuses the tree. Work's failure is the caller's,
   --  and so is the I/O error code it records: the worker starts from the
   --  caller's code and hands its own back once it has finished.
   procedure On_Large_Stack (Work : not null access procedure) is
      Failure     : Ada.Exceptions.Exception_Occurrence;
      Failed      : Boolean := False;
      Caller_Code : constant Integer := Files.IO.Errors.Last_Code;
      Worker_Code : Integer := Caller_Code;
   begin
      declare
         task Worker with Storage_Size => 32 * 1024 * 1024;

         task body Worker is
         begin
            Files.IO.Errors.Adopt_Code (Caller_Code);
            Work.all;
            Worker_Code := Files.IO.Errors.Last_Code;
         exception
            when Error : others =>
               Worker_Code := Files.IO.Errors.Last_Code;
               Ada.Exceptions.Save_Occurrence (Failure, Error);
               Failed := True;
         end Worker;
      begin
         null;
      end;
      --  The worker has terminated: what it left is the caller's to read.
      Files.IO.Errors.Adopt_Code (Worker_Code);
      if Failed then
         Ada.Exceptions.Reraise_Occurrence (Failure);
      end if;
   end On_Large_Stack;

   function Weak_Change_Times (Path : String) return Boolean is
      Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Path);
   begin
      return Hostkit.Fs.Uses_Dos_Filename_Rules (Path)
        or else not Revision.Available
        or else Revision.Changed_Nanoseconds = 0;
   end Weak_Change_Times;

   function Snapshot
     (Path                   : String;
      Content                : Boolean := True;
      Cancel                 : Cancellation_Check := Job_Cancelled;
      Change_Times           : Change_Time_Trust := Decide_Change_Times)
      return Source_Snapshot
   is
      Result : Source_Snapshot;
      Weak_Change_Time : constant Boolean :=
        Content
        and then (case Change_Times is
                     when Decide_Change_Times   => Weak_Change_Times (Path),
                     when Trust_Change_Times    => False,
                     when Distrust_Change_Times => True);
      package Sorting is new Files.Types.String_Vectors.Generic_Sorting;
      procedure Visit (Full_Path, Relative : String; Depth : Natural) is
         Saved_Times : Copy_Times;
         Identity : constant String := Files.File_Identities.Token (Full_Path);
         Is_Directory : constant Boolean :=
           not Hostkit.Fs.Is_Link (Full_Path)
           and then Files.IO.Fs_Primitives.Kind (Full_Path) = Ada.Directories.Directory;
         Revision : constant String := Files.File_Identities.Revision
           (Full_Path, Depth /= 0 and then not Is_Directory);
         Is_Regular_File : constant Boolean :=
           Content and then (Depth = 0 or else Weak_Change_Time)
           and then not Is_Directory and then not Hostkit.Fs.Is_Link (Full_Path)
           and then Files.IO.Fs_Primitives.Kind (Full_Path) = Ada.Directories.Ordinary_File;
         procedure Child (Name : String) is
         begin
            Visit (Hostkit.Fs.Join (Full_Path, Name), Relative & "/" & Name, Depth + 1);
         end Child;
      begin
         if Identity = "" or else Revision = "" or else Depth > 1_024
           or else Natural (Result.Entries.Length) >= Max_Directory_Entries
           or else (Cancel /= null and then Cancel.all)
         then
            raise Ada.Directories.Use_Error;
         end if;
         if not Hostkit.Metadata_Copy.Capture_Times (Full_Path, Saved_Times) then
            raise Ada.Directories.Use_Error;
         end if;
         Result.Times.Insert (Full_Path, Saved_Times);
         declare
            Digest : constant String :=
              (if Is_Regular_File
               then Regular_File_Digest (Full_Path, Cancel)
               else "");
         begin
            if Is_Regular_File
              and then (Files.File_Identities.Token (Full_Path) /= Identity
                or else Files.File_Identities.Revision
                  (Full_Path, Depth /= 0) /= Revision)
            then
               raise Ada.Directories.Use_Error;
            end if;
            if Depth = 0 then
               Result.Root_Identity := To_Unbounded_String (Identity);
            end if;
            Result.Entries.Append (To_Unbounded_String
              (Natural'Image (Relative'Length) & ":" & Relative & Identity & Revision & Digest));
            Result.Shapes.Append (To_Unbounded_String
              (Natural'Image (Relative'Length) & ":" & Relative & Identity & Revision));
         end;
         if Is_Directory then
            For_Each_Entry (Full_Path, Child'Access);
         end if;
      end Visit;
   begin
      Result.Weak_Change_Times := Weak_Change_Time;
      Result.Root_Revision := To_Unbounded_String (Files.File_Identities.Revision (Path));
      if Length (Result.Root_Revision) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      declare
         procedure Visit_Root is
         begin
            Visit (Path, "", 0);
         end Visit_Root;
      begin
         On_Large_Stack (Visit_Root'Access);
      end;
      Sorting.Sort (Result.Entries);
      Sorting.Sort (Result.Shapes);
      return Result;
   end Snapshot;

   function Application_Data_Directory return String is
      function Usable (Root : String) return Boolean is
        (Root /= ""
         and then (for all Item of Root => Item /= ASCII.NUL)
         and then GNAT.OS_Lib.Is_Absolute_Path (Root));
   begin
      if Files.Environment.Is_Set ("FILES_TEST_TEMP") then
         declare
            Root : constant String := Files.Environment.Value ("FILES_TEST_TEMP");
         begin
            return (if Usable (Root) then Hostkit.Fs.Join (Root, "data") else "");
         end;
      end if;
      declare
         Root : constant String := Hostkit.Fs.Application_Data_Directory;
      begin
         return (if Usable (Root) then Root else "");
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
         return "";
   end Application_Data_Directory;

   function Files_Data_Directory return String is
      Data : constant String := Application_Data_Directory;
   begin
      return (if Data = "" then "" else Hostkit.Fs.Join (Data, Files.Protocol_Names.Data_Folder));
   end Files_Data_Directory;

   function With_Root_Content (Snapshot : Source_Snapshot; Digest : String) return Source_Snapshot is
      package Sorting is new Files.Types.String_Vectors.Generic_Sorting;
      --  The root is the one entry with an empty relative path.
      Root_Prefix : constant String := Natural'Image (0) & ":";
      Result : Source_Snapshot := Snapshot;
   begin
      if Digest = "" then
         return Result;
      end if;
      for Item of Result.Entries loop
         if Length (Item) >= Root_Prefix'Length
           and then Slice (Item, 1, Root_Prefix'Length) = Root_Prefix
         then
            Append (Item, Digest);
         end if;
      end loop;
      Sorting.Sort (Result.Entries);
      return Result;
   end With_Root_Content;

   function Regular_File_Digest
     (Path   : String;
      Cancel : Cancellation_Check := Job_Cancelled) return String
   is
      use Ada.Streams;
      use type GNAT.OS_Lib.File_Descriptor;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Supported : Boolean;
      Buffer : Stream_Element_Array (1 .. Files.Types.IO_Chunk_Bytes);
      Bytes_Read : Integer;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
   begin
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      Descriptor := Hostkit.Regular_Files.Open_Read (Path, False, Supported);
      pragma Unreferenced (Supported);
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         --  Refused a link, a non-regular entry, or failed to open; or a host
         --  without the native open (none that is built for). A pathname
         --  open instead would reintroduce the race it guards against.
         raise Ada.Directories.Use_Error;
      end if;
      begin
         loop
            if Cancel /= null and then Cancel.all then
               raise Ada.Directories.Use_Error;
            end if;
            Bytes_Read := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, Integer (Buffer'Length));
            if Bytes_Read < 0 then
               raise Ada.Directories.Use_Error;
            end if;
            exit when Bytes_Read = 0;
            CryptoLib.Hashes.Update
              (Context, Buffer (Buffer'First .. Buffer'First + Stream_Element_Offset (Bytes_Read) - 1));
         end loop;
         GNAT.OS_Lib.Close (Descriptor);
         Descriptor := GNAT.OS_Lib.Invalid_FD;
      end;
      Digest := CryptoLib.Hashes.Finalize (Context);
      return Files.File_System.Digests.Hex (Digest);
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         raise;
   end Regular_File_Digest;

   function Tree_Revision (Path : String) return String is (Tree_Revision_Of (Path, Job_Cancelled));

   function Tree_Revision_Of (Path : String; Cancel : Cancellation_Check) return String is
      State : Source_Snapshot;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;

      procedure Add (Text : String) is
      begin
         Files.File_System.Digests.Update (Context, Text);
      end Add;

      --  Listing a directory may advance its access time, which would undo a
      --  copy's preserved times. Put back only that: the modification time is
      --  left as it is now, so an entry created meanwhile is not hidden, and
      --  a directory whose times cannot be set (another owner's) is skipped
      --  rather than voiding the revision.
      procedure Restore_Directory_Times is
      begin
         for Cursor in State.Times.Iterate loop
            declare
               Item_Path : constant String := Source_Time_Maps.Key (Cursor);
               Saved     : constant Copy_Times := Source_Time_Maps.Element (Cursor);
               Current   : Copy_Times;
            begin
               if not Hostkit.Fs.Is_Link (Item_Path)
                 and then Files.IO.Fs_Primitives.Kind (Item_Path) = Ada.Directories.Directory
                 and then Hostkit.Metadata_Copy.Capture_Times (Item_Path, Current)
                 and then Current (3 .. 4) = Saved (3 .. 4)
                 and then Current (1 .. 2) /= Saved (1 .. 2)
               then
                  Current (1 .. 2) := Saved (1 .. 2);
                  declare
                     Applied : constant Boolean := Hostkit.Metadata_Copy.Apply_Times (Item_Path, Current);
                     pragma Unreferenced (Applied);
                  begin
                     null;
                  end;
               end if;
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
            end;
         end loop;
      end Restore_Directory_Times;
   begin
      if Hostkit.Fs.Is_Link (Path) then
         return "";
      end if;
      if Files.IO.Fs_Primitives.Kind (Path) = Ada.Directories.Ordinary_File then
         declare
            Identity : constant String := Files.File_Identities.Token (Path);
            Full_Revision : constant String := Files.File_Identities.Revision (Path);
            Stable_Revision : constant String := Files.File_Identities.Revision (Path, False);
         begin
            if Identity = "" or else Full_Revision = "" or else Stable_Revision = "" then
               return "";
            end if;
            declare
               Digest : constant String :=
                 Regular_File_Digest (Path, Cancel);
            begin
               if Files.File_Identities.Token (Path) /= Identity
                 or else Files.File_Identities.Revision (Path) /= Full_Revision
               then
                  return "";
               end if;
               return "file:" & Stable_Revision & ":" & Digest;
            end;
         end;
      elsif Files.IO.Fs_Primitives.Kind (Path) /= Ada.Directories.Directory then
         return "";
      end if;
      State := Snapshot (Path, Cancel => Cancel);
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      for Item of State.Entries loop
         declare
            Text : constant String := To_String (Item);
         begin
            Add (Files.Text_Basics.Natural_Text (Text'Length) & ":" & Text);
         end;
      end loop;
      Restore_Directory_Times;
      Digest := CryptoLib.Hashes.Finalize (Context);
      return Files.File_System.Digests.Hex (Digest);
   end Tree_Revision_Of;

   function Move_No_Replace (Source, Destination : String) return Boolean is
     (Move_No_Replace_Outcome (Source, Destination) = Hostkit.Fs.Moved);

   function Move_No_Replace_Outcome
     (Source, Destination : String)
      return Hostkit.Fs.Move_Outcome
   is
      Context  : Hostkit.Directory_Write_Access.Context;
      Outcome  : Hostkit.Fs.Move_Outcome;
      Moved    : Boolean := False;
      Restored : Boolean;

      --  Give the folder back its mode, wherever it is now -- unless the
      --  test suite refuses that there (Refuse_Directory_Restore).
      function Finish return Boolean is
         Refuse : constant Restore_Hook := Refuse_Directory_Restore;
      begin
         if Refuse /= null and then Refuse (if Moved then Destination else Source) then
            return False;
         end if;
         return Hostkit.Directory_Write_Access.Finish (Context);
      end Finish;
   begin
      if not Hostkit.Directory_Write_Access.Prepare (Source, Context) then
         return Hostkit.Fs.Move_Refused;
      end if;
      Files.IO.Errors.Clear_Os_Error;
      Outcome := Hostkit.Fs.Move_No_Replace_Outcome (Source, Destination);
      Moved := Outcome = Hostkit.Fs.Moved;
      if not Moved then
         --  Before restoring access below, which makes calls of its own.
         Files.IO.Errors.Capture;
      end if;
      Restored := Finish;
      if not Restored then
         --  Restore the original pathname before reporting a refused operation.
         --  If that pathname is occupied, leave the committed payload in place.
         if Moved and then Hostkit.Fs.Move_No_Replace (Destination, Source) then
            Moved := False;
         end if;
         Restored := Finish;
         if not Restored then
            Hostkit.Directory_Write_Access.Release (Context);
         end if;
         raise Ada.Directories.Use_Error;
      end if;
      return Outcome;
   exception
      when others =>
         Restored := Finish;
         if not Restored then
            Hostkit.Directory_Write_Access.Release (Context);
         end if;
         raise;
   end Move_No_Replace_Outcome;

   procedure Delete_Owned_Tree (Path : String) is
      procedure Delete_Owned_Level (Path : String);

      procedure Delete_Root is
      begin
         Delete_Owned_Level (Path);
      end Delete_Root;

      procedure Delete_Owned_Level (Path : String) is
         --  The files that make a folder one of ours, in the order they go:
         --  a recovery stage's markers, then the owner file that names whose
         --  stage it is; a transport's marker, then its lease.
         subtype Held_Index is Positive range 1 .. 5;
         function Held_Back (Index : Held_Index) return String is
           (case Index is
               when 1 => Files.Protocol_Names.Recovery_Vacated,
               when 2 => Files.Protocol_Names.Recovery_Releasing,
               when 3 => Files.Protocol_Names.Recovery_Owner,
               when 4 => Files.Protocol_Names.Transport_Marker,
               when 5 => Files.Protocol_Names.Transport_Lease);
         Present   : array (Held_Index) of Boolean := [others => False];
         Available : Boolean;
         Mode : Natural;
         procedure Delete_Entry (Name : String) is
            Refuse : constant Restore_Hook := Refuse_Owned_Delete;
         begin
            for Index in Held_Index loop
               if Name = Held_Back (Index) then
                  Present (Index) := True;
                  return;
               end if;
            end loop;
            if Refuse /= null and then Refuse (Hostkit.Fs.Join (Path, Name)) then
               raise Ada.Directories.Use_Error;
            end if;
            Delete_Owned_Level (Hostkit.Fs.Join (Path, Name));
         end Delete_Entry;
      begin
         if Hostkit.Fs.Is_Link (Path) or else Files.IO.Fs_Primitives.Kind (Path) /= Ada.Directories.Directory then
            Files.IO.Fs_Primitives.Delete_Tree (Path);
            return;
         end if;
         if Hostkit.Metadata.Mode_Bits_Are_Native then
            Mode := Hostkit.Metadata.File_Permission_Bits (Path, Available);
            if not Available or else not Hostkit.Metadata.Set_Permissions
              (Path, (Mode mod 8#100#) + 8#700#)
            then
               raise Ada.Directories.Use_Error;
            end if;
         end if;
         For_Each_Entry (Path, Delete_Entry'Access);
         --  Keep what marks the folder as ours until every other child is
         --  gone. If one cannot be removed (a Windows sharing violation,
         --  EACCES), the folder still carries its markers and owner and stays
         --  reclaimable: the recovery sweep, cleanup and the scavenger finish
         --  it later; without them they refuse it forever.
         for Index in Held_Index loop
            if Present (Index) then
               Delete_Owned_Level (Hostkit.Fs.Join (Path, Held_Back (Index)));
            end if;
         end loop;
         --  Only ever the emptied directory: a Windows read-only folder (kept
         --  from its source by the copy) is cleared first, not refused.
         if not Hostkit.Fs.Delete_Empty_Directory (Path) then
            raise Ada.Directories.Use_Error;
         end if;
      end Delete_Owned_Level;
   begin
      --  A stage can be as deep as a copy (1024 levels): on a stack that
      --  holds it, not the caller's (1 MiB on Windows' main thread).
      On_Large_Stack (Delete_Root'Access);
   end Delete_Owned_Tree;

end Files.File_System.Support;
