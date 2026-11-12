with Files.Protocol_Names;
with Interfaces;
with Ada.Streams;
with Files.Environment;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;
with Files.Job_Context;
with Hostkit.Directory_Write_Access;
with Files.File_Identities;
with Files.Io_Errors;
with CryptoLib.Hashes;

with Files.Durability;
with Hostkit.Durability;
with Hostkit.Host;
with Hostkit.Metadata;
with Hostkit.Regular_Files;
with Files.Path_Checks;

package body Files.File_System.Support is

   --  @param Batch Batch journal to load.
   --  @return Verified source-to-destination records for this batch.
   function Load_Links (Batch : Files.Copy_Context.Session) return Copied_File_Maps.Map;

   --  @param Batch Batch journal to update.
   --  @param Links Source identity records, including this newly published root.
   --  @param Stage Private payload prefix to replace after publication.
   --  @param Destination Published payload prefix.
   procedure Save_Links
     (Batch : Files.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String);

   --  As Tree_Revision, optionally for recovery that must finish after
   --  cancellation.
   --
   --  @param Path Existing entry to inspect without following symbolic links.
   --  @param Check_Job_Cancellation False to keep going once the job is cancelled.
   --  @return As Tree_Revision.
   function Tree_Revision_Of (Path : String; Check_Job_Cancellation : Boolean) return String;

   --  The most entries one directory may list before it counts as hostile.
   Max_Directory_Entries : constant := 1_000_000;
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Move_Outcome;
   use type Interfaces.Unsigned_64;

   procedure On_Large_Stack (Work : not null access procedure);

   function Sync_Copy (Source, Destination : String; Files_Too : Boolean := True) return Boolean is
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
         if Hostkit.Fs.Is_Link (To) or else not Files.Fs_Primitives.Entry_Exists (To) then
            return;
         elsif Files.Fs_Primitives.Kind (To) = Ada.Directories.Directory then
            if not Hostkit.Fs.Is_Link (From) then
               For_Each_Entry (From, Visit'Access);
            end if;
            Synced := Synced
              and then Files.Durability.Sync_Directory (To) /= Hostkit.Durability.Failed;
         elsif Files_Too and then Files.Fs_Primitives.Kind (To) = Ada.Directories.Ordinary_File then
            Synced := Files.Durability.Sync_File (To) /= Hostkit.Durability.Failed;
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
        and then Files.Durability.Sync_Directory (Files.Fs_Primitives.Parent_Directory (Destination)) /=
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
      Files.Fs_Primitives.For_Each_Name (Path, Collect'Access);
      --  Recursion retains neither a large buffer nor an open directory.
      for Name of Names loop
         Visit (To_String (Name));
      end loop;
   end For_Each_Entry;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Types.To_Lower (Files.Environment.Value (Name)) = Expected;
   end Environment_Equals;

   function Natural_Text (Value : Natural) return String renames Files.Types.Natural_Text;

   function Create_Stage (Parent : String) return String renames Files.Job_Context.Create_Stage;

   overriding function "=" (Left, Right : Source_Snapshot) return Boolean is
      use type Files.Types.String_Vectors.Vector;
   begin
      return Left.Root_Revision = Right.Root_Revision and then Left.Entries = Right.Entries;
   end "=";

   function Regular_File_Digest
     (Path                   : String;
      Cancel                 : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True) return String;

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
      Caller_Code : constant Integer := Files.Io_Errors.Last_Code;
      Worker_Code : Integer := Caller_Code;
   begin
      declare
         task Worker with Storage_Size => 32 * 1024 * 1024;

         task body Worker is
         begin
            Files.Io_Errors.Adopt_Code (Caller_Code);
            Work.all;
            Worker_Code := Files.Io_Errors.Last_Code;
         exception
            when Error : others =>
               Worker_Code := Files.Io_Errors.Last_Code;
               Ada.Exceptions.Save_Occurrence (Failure, Error);
               Failed := True;
         end Worker;
      begin
         null;
      end;
      --  The worker has terminated: what it left is the caller's to read.
      Files.Io_Errors.Adopt_Code (Worker_Code);
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
      Check_Job_Cancellation : Boolean := True;
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
           and then Files.Fs_Primitives.Kind (Full_Path) = Ada.Directories.Directory;
         Revision : constant String := Files.File_Identities.Revision
           (Full_Path, Depth /= 0 and then not Is_Directory);
         Is_Regular_File : constant Boolean :=
           Content and then (Depth = 0 or else Weak_Change_Time)
           and then not Is_Directory and then not Hostkit.Fs.Is_Link (Full_Path)
           and then Files.Fs_Primitives.Kind (Full_Path) = Ada.Directories.Ordinary_File;
         procedure Child (Name : String) is
         begin
            Visit (Hostkit.Fs.Join (Full_Path, Name), Relative & "/" & Name, Depth + 1);
         end Child;
      begin
         if Identity = "" or else Revision = "" or else Depth > 1_024
           or else Natural (Result.Entries.Length) >= Max_Directory_Entries
           or else (Check_Job_Cancellation and then Files.Job_Context.Cancelled)
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
               then Regular_File_Digest (Full_Path, Check_Job_Cancellation => Check_Job_Cancellation)
               else "");
         begin
            if Is_Regular_File
              and then (Files.File_Identities.Token (Full_Path) /= Identity
                or else Files.File_Identities.Revision
                  (Full_Path, Depth /= 0) /= Revision)
            then
               raise Ada.Directories.Use_Error;
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
     (Path                   : String;
      Cancel                 : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True) return String
   is
      use Ada.Streams;
      use type GNAT.OS_Lib.File_Descriptor;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Supported : Boolean;
      Buffer : Stream_Element_Array (1 .. 65_536);
      Bytes_Read : Integer;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);
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
            if (Cancel /= null and then Cancel.all)
              or else
                (Check_Job_Cancellation and then Files.Job_Context.Cancelled)
            then
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
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         raise;
   end Regular_File_Digest;

   function Tree_Revision (Path : String) return String is (Tree_Revision_Of (Path, Check_Job_Cancellation => True));

   function Tree_Revision_Of (Path : String; Check_Job_Cancellation : Boolean) return String is
      use Ada.Streams;
      State : Source_Snapshot;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);

      procedure Add (Text : String) is
         Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
      begin
         for Index in Text'Range loop
            Data (Stream_Element_Offset (Index - Text'First + 1)) := Character'Pos (Text (Index));
         end loop;
         if Data'Length > 0 then
            CryptoLib.Hashes.Update (Context, Data);
         end if;
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
                 and then Files.Fs_Primitives.Kind (Item_Path) = Ada.Directories.Directory
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
      if Files.Fs_Primitives.Kind (Path) = Ada.Directories.Ordinary_File then
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
                 Regular_File_Digest (Path, Check_Job_Cancellation => Check_Job_Cancellation);
            begin
               if Files.File_Identities.Token (Path) /= Identity
                 or else Files.File_Identities.Revision (Path) /= Full_Revision
               then
                  return "";
               end if;
               return "file:" & Stable_Revision & ":" & Digest;
            end;
         end;
      elsif Files.Fs_Primitives.Kind (Path) /= Ada.Directories.Directory then
         return "";
      end if;
      State := Snapshot (Path, Check_Job_Cancellation => Check_Job_Cancellation);
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      for Item of State.Entries loop
         declare
            Text : constant String := To_String (Item);
         begin
            Add (Natural_Text (Text'Length) & ":" & Text);
         end;
      end loop;
      Restore_Directory_Times;
      Digest := CryptoLib.Hashes.Finalize (Context);
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
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
      Files.Io_Errors.Clear_Os_Error;
      Outcome := Hostkit.Fs.Move_No_Replace_Outcome (Source, Destination);
      Moved := Outcome = Hostkit.Fs.Moved;
      if not Moved then
         --  Before restoring access below, which makes calls of its own.
         Files.Io_Errors.Capture;
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

   procedure Check_Copy_Destination (Source, Destination : String) is
   begin
      if Hostkit.Fs.Is_Link (Source) or else Files.Fs_Primitives.Kind (Source) /= Ada.Directories.Directory then
         return;
      end if;
      declare
         --  Links resolved, on Windows too: a copy into its own tree reached
         --  through a link or junction is still a copy into its own tree.
         Original : constant String := Files.Fs_Primitives.Real_Name (Source);
         Identity : constant String := Files.File_Identities.Token (Source);
         Parent : UString := To_Unbounded_String
           (Files.Fs_Primitives.Real_Name (Files.Fs_Primitives.Parent_Directory (Destination)));
      begin
         if Original = "" or else Length (Parent) = 0 then
            raise Ada.Directories.Use_Error;
         end if;
         loop
            if To_String (Parent) = Original
              or else (Identity /= "" and then Files.File_Identities.Token (To_String (Parent)) = Identity)
            then
               raise Ada.Directories.Use_Error;
            end if;
            declare
               Next : constant String :=
                 Files.Fs_Primitives.Real_Name (Hostkit.Fs.Join (To_String (Parent), ".."));
            begin
               if Next = "" then
                  raise Ada.Directories.Use_Error;
               end if;
               exit when Next = To_String (Parent);
               Parent := To_Unbounded_String (Next);
            end;
         end loop;
      end;
   end Check_Copy_Destination;

   function Load_Links (Batch : Files.Copy_Context.Session) return Copied_File_Maps.Map is
      Items : constant Files.Types.String_Vectors.Vector := Files.Copy_Context.Records (Batch);
      Links : Copied_File_Maps.Map;
      Index : Positive := 1;

      function Nul_Free (Value : String) return Boolean renames Files.Path_Checks.Nul_Free;

      function Valid_Absolute_Path (Path : String) return Boolean is
        (Files.Path_Checks.Valid_Absolute_Path (Path));
   begin
      if Natural (Items.Length) mod 6 /= 0 then
         raise Ada.Directories.Use_Error;
      end if;
      while Index <= Items.Last_Index loop
         --  Copy_Context is deliberately only a bounded transport.  Validate
         --  the hard-link schema here before a persisted pathname can be used
         --  for identity checks, digest reads, or link creation.
         if Length (Items (Index)) = 0
           or else Length (Items (Index + 1)) = 0
           or else Length (Items (Index + 2)) = 0
           or else not Valid_Absolute_Path (To_String (Items (Index + 3)))
           or else Length (Items (Index + 4)) = 0
           or else Length (Items (Index + 5)) = 0
           or else not Nul_Free (To_String (Items (Index)))
           or else not Nul_Free (To_String (Items (Index + 1)))
           or else not Nul_Free (To_String (Items (Index + 2)))
           or else not Nul_Free (To_String (Items (Index + 4)))
           or else not Nul_Free (To_String (Items (Index + 5)))
           or else Links.Contains (To_String (Items (Index)))
         then
            raise Ada.Directories.Use_Error;
         end if;
         Links.Insert
           (To_String (Items (Index)),
            (Path                 => Items (Index + 3),
             Identity             => Items (Index + 4),
             Source_Revision      => Items (Index + 1),
             Destination_Revision => Items (Index + 5),
             Content_Digest       => Items (Index + 2)));
         Index := Index + 6;
      end loop;
      return Links;
   end Load_Links;

   procedure Save_Links
     (Batch : Files.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String) is
      Items : Files.Types.String_Vectors.Vector;
   begin
      for Cursor in Links.Iterate loop
         declare
            Item : constant Copied_File := Copied_File_Maps.Element (Cursor);
            Path : constant String := To_String (Item.Path);
            Published : constant String := Hostkit.Fs.Rebase (Path, Stage, Destination);
         begin
            Items.Append (To_Unbounded_String (Copied_File_Maps.Key (Cursor)));
            Items.Append (Item.Source_Revision);
            Items.Append (Item.Content_Digest);
            Items.Append (To_Unbounded_String (Published));
            Items.Append (Item.Identity);
            Items.Append (Item.Destination_Revision);
         end;
      end loop;
      Files.Copy_Context.Save (Batch, Items);
   end Save_Links;

   --  What one copy walk carries through every level of the tree: how it
   --  is stopped, what it keeps, what it shares, and what it reports.
   type Copy_Walk is limited record
      Cancel                 : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times                  : Source_Time_Maps.Map;
      Preserve_Ownership     : Boolean := False;
      --  Files already copied, by source identity: hard links stay links.
      Copied_Files           : Copied_File_Maps.Map;
      Shared_Batch           : Boolean := False;
      --  Each regular file is flushed to the device through the descriptor
      --  that wrote it, before its metadata is set (a move removes its
      --  source after the walk; Windows may then make the file read-only).
      Durable                : Boolean := False;
      --  Whether to digest the root file's bytes, and the digest.
      Want_Root_Digest       : Boolean := False;
      Root_Digest            : Files.Types.UString;
   end record;

   procedure Copy_Node
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural;
      Walk             : in out Copy_Walk);

   --  Copy_Node on a large stack (On_Large_Stack): its 1024 levels take about
   --  2 KB each.
   procedure Copy_Node_Deep
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural;
      Walk             : in out Copy_Walk)
   is
      procedure Copy is
      begin
         Copy_Node (Source_Path, Destination_Path, Depth, Walk);
      end Copy;
   begin
      On_Large_Stack (Copy'Access);
   end Copy_Node_Deep;

   procedure Copy_To_New_Path
     (Source_Path : String; Destination_Path : String; Cancel : Cancellation_Check := null;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session) is
      Identity : Files.Types.UString;
   begin
      Copy_To_New_Path (Source_Path, Destination_Path, Identity, Cancel,
                        Preserve_Ownership => Preserve_Ownership, Batch => Batch);
   end Copy_To_New_Path;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
   is
      Tree_Revision_Value : Files.Types.UString;
   begin
      Copy_To_New_Path
        (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Cancel, Times,
         Preserve_Ownership, Batch);
   end Copy_To_New_Path;

   --  Give a copy just published from its private stage the access its new
   --  folder hands down, and its revision afresh where that changed it.
   procedure Inherit_Destination_Access
     (Path                   : String;
      Revision               : in out Files.Types.UString;
      Check_Job_Cancellation : Boolean) is
   begin
      --  The stage handed the payload its owner-only access, and a rename
      --  into place keeps that on Windows. What the destination hands down
      --  is the copy's, as for any file made there (files copies no DACL: a
      --  copy inherits, as Explorer's does). A failure leaves the copy
      --  owner-only, which is no reason to undo a finished copy.
      if not Hostkit.Metadata.Inherit_From_Parent (Path) then
         return;
      end if;
      --  Inheriting wrote the change time of every entry it reached, which a
      --  folder's revision reads for the files inside it: take it afresh, or
      --  Undo and crash recovery would see a changed copy. A file's revision
      --  leaves the change time out.
      if Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows)
        and then not Hostkit.Fs.Is_Link (Path)
        and then Files.Fs_Primitives.Kind (Path) = Ada.Directories.Directory
      then
         Revision := To_Unbounded_String (Tree_Revision_Of (Path, Check_Job_Cancellation));
      end if;
   end Inherit_Destination_Access;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session;
      Root_Digest : access Files.Types.UString := null;
      Check_Job_Cancellation : Boolean := True;
      Durable : Boolean := False)
   is
      Stage : UString;
      Walk  : Copy_Walk :=
        (Cancel                 => Cancel,
         Check_Job_Cancellation => Check_Job_Cancellation,
         Times                  => Times,
         Preserve_Ownership     => Preserve_Ownership,
         Copied_Files           => Load_Links (Batch),
         Shared_Batch           => Files.Copy_Context.Directory (Batch) /= "",
         Durable                => Durable,
         Want_Root_Digest       => True,
         Root_Digest            => Null_Unbounded_String);
      Copied_Digest : Files.Types.UString renames Walk.Root_Digest;
   begin
      if Root_Digest /= null then
         Root_Digest.all := Null_Unbounded_String;
      end if;
      Identity := Null_Unbounded_String;
      Tree_Revision_Value := Null_Unbounded_String;
      Check_Copy_Destination (Source_Path, Destination_Path);
      Stage := To_Unbounded_String (Create_Stage (Files.Fs_Primitives.Parent_Directory (Destination_Path)));
      Copy_Node_Deep (Source_Path, Hostkit.Fs.Join (To_String (Stage), "payload"), 0, Walk);
      Identity := To_Unbounded_String (Files.File_Identities.Token (Hostkit.Fs.Join (To_String (Stage), "payload")));
      if Root_Digest /= null then
         Root_Digest.all := Copied_Digest;
      end if;
      declare
         Payload : constant String := Hostkit.Fs.Join (To_String (Stage), "payload");
      begin
         if not Hostkit.Fs.Is_Link (Payload)
           and then Files.Fs_Primitives.Kind (Payload) = Ada.Directories.Ordinary_File
         then
            declare
               Revision : constant String := Files.File_Identities.Revision (Payload, False);
            begin
               if Revision /= "" and then Length (Copied_Digest) = 64 then
                  Tree_Revision_Value := To_Unbounded_String
                    ("file:" & Revision & ":" & To_String (Copied_Digest));
               end if;
            end;
         else
            Tree_Revision_Value := To_Unbounded_String (Tree_Revision_Of (Payload, Check_Job_Cancellation));
         end if;
      end;
      --  Never publish an unidentifiable payload: Undo and crash recovery
      --  could not verify it afterward, even if staging succeeded.
      if Length (Identity) = 0
        or else (not Hostkit.Fs.Is_Link (Hostkit.Fs.Join (To_String (Stage), "payload"))
          and then Length (Tree_Revision_Value) = 0)
      then
         raise Ada.Directories.Use_Error;
      end if;
      Save_Links (Batch, Walk.Copied_Files, Hostkit.Fs.Join (To_String (Stage), "payload"), Destination_Path);
      if not Move_No_Replace (Hostkit.Fs.Join (To_String (Stage), "payload"), Destination_Path) then
         raise Ada.Directories.Use_Error;
      end if;
      Inherit_Destination_Access (Destination_Path, Tree_Revision_Value, Check_Job_Cancellation);
      Files.Job_Context.Record_Created
        (Destination_Path, Source_Path, To_String (Identity), To_String (Tree_Revision_Value));
      --  Publication is complete; leftover staging must not falsify its result.
      declare
         Removed : constant Boolean := Files.Job_Context.Discard_Stage (To_String (Stage));
         pragma Unreferenced (Removed);
      begin
         null;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
      end;
   exception
      when others =>
         begin
            if Length (Stage) > 0 then
               declare
                  Removed : constant Boolean := Files.Job_Context.Discard_Stage (To_String (Stage));
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            end if;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
         end;
         raise;
   end Copy_To_New_Path;

   --  Recursively copy a file/directory tree. Used as the cross-device
   --  fallback when Ada.Directories.Rename fails with EXDEV (it cannot move
   --  across filesystems), by both trashing and drag-and-drop moves.
   --  Stop a copy the user or the job cancelled.
   procedure Check_Cancelled (Walk : Copy_Walk) is
   begin
      if (Walk.Cancel /= null and then Walk.Cancel.all)
        or else (Walk.Check_Job_Cancellation and then Files.Job_Context.Cancelled)
      then
         raise Program_Error;
      end if;
   end Check_Cancelled;

   --  What one Copy_Node step learns as it goes. Limited, so passed by
   --  reference: Owned is still right in the walk's handler after a raise.
   type Node_State is limited record
      --  Whether the destination is this step's to remove on failure.
      Owned           : Boolean := False;
      Source_Identity : Files.Types.UString;
      Source_Revision : Files.Types.UString;
      --  Whether the source is (or may be) one inode of several to keep as links.
      Track_Hard_Link : Boolean := False;
      --  The digest of the bytes Copy_File_Bytes read and wrote, when asked.
      Copied_Digest   : Files.Types.UString;
   end record;

   --  The SHA-256 of an entry's content: a regular file's bytes, a link's target.
   function Content_Digest (Path : String; Walk : Copy_Walk) return String is
      use Ada.Streams;
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);

      procedure Add (Data : Stream_Element_Array) is
      begin
         if Data'Length > 0 then
            CryptoLib.Hashes.Update (Context, Data);
         end if;
      end Add;
   begin
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      if Hostkit.Fs.Is_Link (Path) then
         declare
            Target : UString;
         begin
            if not Hostkit.Fs.Read_Link_Target (Path, Target) then
               raise Ada.Directories.Use_Error;
            end if;
            declare
               Text : constant String := To_String (Target);
               Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
            begin
               for Index in Text'Range loop
                  Data (Stream_Element_Offset (Index - Text'First + 1)) := Character'Pos (Text (Index));
               end loop;
               Add (Data);
            end;
         end;
      else
         --  Use the descriptor-pinned, no-follow regular-file reader.  A
         --  pathname open after the classification above could otherwise
         --  follow a replacement symlink or block on a replacement FIFO.
         return Regular_File_Digest
           (Path, Walk.Cancel, Walk.Check_Job_Cancellation);
      end if;
      Digest := CryptoLib.Hashes.Finalize (Context);
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) := Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) := Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
   end Content_Digest;

   --  Make Destination a hard link to the copy of Source's inode already made
   --  in this walk, after checking neither changed since.
   --
   --  @return False when Source is not an inode the walk copied before.
   function Copy_Hard_Link
     (Source_Path      : String;
      Destination_Path : String;
      Walk             : in out Copy_Walk;
      Metadata         : in out Hostkit.Metadata_Copy.Snapshot;
      Wants_Digest     : Boolean;
      State            : in out Node_State)
      return Boolean
   is
      Copied_Files    : Copied_File_Maps.Map renames Walk.Copied_Files;
      Source_Identity : Files.Types.UString renames State.Source_Identity;
      Source_Revision : Files.Types.UString renames State.Source_Revision;
      Links : Interfaces.Unsigned_64;
   begin
      Links := Hostkit.Metadata_Copy.Link_Count (Metadata);
      if Walk.Shared_Batch or else Links > 1 then
         Source_Identity := To_Unbounded_String (Files.File_Identities.Token (Source_Path));
         Source_Revision := To_Unbounded_String (Files.File_Identities.Revision (Source_Path, False));
         if Length (Source_Identity) = 0 then
            raise Ada.Directories.Use_Error;
         end if;
         State.Track_Hard_Link := Links > 1 or else Copied_Files.Contains (To_String (Source_Identity));
      end if;
      if Length (Source_Identity) > 0 and then Copied_Files.Contains (To_String (Source_Identity)) then
         declare
            First : constant Copied_File := Copied_Files.Element (To_String (Source_Identity));
         begin
            --  The source is the inode already copied, unchanged since, and
            --  the first copy still holds what was written: in a retried
            --  batch it is a published file that may have been edited (a
            --  same-size edit with its time put back shows only in content).
            if Files.File_Identities.Revision (Source_Path, False) /= To_String (First.Source_Revision)
              or else Content_Digest (Source_Path, Walk) /= To_String (First.Content_Digest)
              or else Files.File_Identities.Token (To_String (First.Path)) /= To_String (First.Identity)
              or else Files.File_Identities.Revision (To_String (First.Path), False)
                /= To_String (First.Destination_Revision)
              or else Content_Digest (To_String (First.Path), Walk) /= To_String (First.Content_Digest)
            then
               raise Ada.Directories.Use_Error;
            end if;
            if not Hostkit.Fs.Create_Hard_Link (To_String (First.Path), Destination_Path) then
               raise Ada.Directories.Use_Error;
            end if;
            State.Owned := True;
            --  The new link is the first copy's inode (same identity), so
            --  its content is that copy's; only metadata can have moved.
            if Files.File_Identities.Revision (Source_Path, False) /= To_String (First.Source_Revision)
              or else Files.File_Identities.Token (To_String (First.Path)) /= To_String (First.Identity)
              or else Files.File_Identities.Token (Destination_Path) /= To_String (First.Identity)
              or else Files.File_Identities.Revision (To_String (First.Path), False)
                /= To_String (First.Destination_Revision)
              or else Files.File_Identities.Revision (Destination_Path, False)
                /= To_String (First.Destination_Revision)
            then
               raise Ada.Directories.Use_Error;
            end if;
            Check_Cancelled (Walk);
            Metadata := Hostkit.Metadata_Copy.No_Snapshot;
            if Wants_Digest and then not Hostkit.Fs.Is_Link (Source_Path) then
               Walk.Root_Digest := First.Content_Digest;
            end if;
            return True;
         end;
      end if;
      return False;
   end Copy_Hard_Link;

   --  Copy a regular file's bytes into a new file, sparse where the source
   --  reads as zeros, flushed when the walk is durable; digested when asked
   --  (into State.Copied_Digest, and the walk's root digest for the root).
   --  Encrypted makes the new file encrypted before its first byte (an EFS
   --  source on Windows): the copy fails rather than land decrypted.
   procedure Copy_File_Bytes
     (Source_Path      : String;
      Destination_Path : String;
      Walk             : in out Copy_Walk;
      Wants_Digest     : Boolean;
      Encrypted        : Boolean;
      State            : in out Node_State)
   is
      Track_Hard_Link     : Boolean renames State.Track_Hard_Link;
      Copied_Bytes_Digest : Files.Types.UString renames State.Copied_Digest;
      use Ada.Streams;
      use type GNAT.OS_Lib.File_Descriptor;
      Input_Descriptor : GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Invalid_FD;
      Output : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer : Stream_Element_Array (1 .. 65_536);
      Last   : Stream_Element_Offset;
      Next   : Stream_Element_Offset;
      Bytes_Read : Integer;
      Wrote  : Integer;
      Closed : Boolean;
      Sparse : Boolean := False;
      Digest_Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Digest_Text : String (1 .. 64);
      procedure Copy_Buffer (Buffer_Last : Stream_Element_Offset) is
      begin
         if (Wants_Digest or else Track_Hard_Link)
           and then Buffer_Last >= Buffer'First
         then
            CryptoLib.Hashes.Update
              (Digest_Context, Buffer (Buffer'First .. Buffer_Last));
         end if;
         Next := Buffer'First;
         if Buffer_Last >= Buffer'First
           and then
             (for all Index in Buffer'First .. Buffer_Last =>
                Buffer (Index) = 0)
           and then Hostkit.Regular_Files.Skip_Zeros
             (Output, Integer (Buffer_Last - Buffer'First + 1))
         then
            Sparse := True;
            Next := Buffer_Last + 1;
         end if;
         while Next <= Buffer_Last loop
            Wrote := GNAT.OS_Lib.Write
              (Output, Buffer (Next)'Address,
               Integer (Buffer_Last - Next + 1));
            if Wrote <= 0 then
               Files.Io_Errors.Capture;
               raise Ada.Directories.Use_Error;
            end if;
            Next := Next + Stream_Element_Offset (Wrote);
         end loop;
      end Copy_Buffer;
   begin
      Copied_Bytes_Digest := Null_Unbounded_String;
      if Wants_Digest or else Track_Hard_Link then
         CryptoLib.Hashes.Initialize_SHA256 (Digest_Context);
      end if;
      declare
         Supported : Boolean;
      begin
         Input_Descriptor := Hostkit.Regular_Files.Open_Read
           (Source_Path, False, Supported);
         pragma Unreferenced (Supported);
         --  Refused a link or a non-regular entry, or failed to open: no
         --  pathname open instead, which would reopen the race it guards.
         if Input_Descriptor = GNAT.OS_Lib.Invalid_FD then
            Files.Io_Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
      end;
      --  0666 less the creation mask, as GNAT's Create_New_File makes it.
      Output := Hostkit.Regular_Files.Create_New (Destination_Path, 8#666#, Encrypted);
      if Output = GNAT.OS_Lib.Invalid_FD then
         Files.Io_Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      State.Owned := True;
      loop
         Check_Cancelled (Walk);
         Bytes_Read := GNAT.OS_Lib.Read
           (Input_Descriptor, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0 then
            Files.Io_Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
         exit when Bytes_Read = 0;
         Last := Buffer'First + Stream_Element_Offset (Bytes_Read) - 1;
         Copy_Buffer (Last);
      end loop;
      GNAT.OS_Lib.Close (Input_Descriptor);
      Input_Descriptor := GNAT.OS_Lib.Invalid_FD;
      if Sparse and then not Hostkit.Regular_Files.Finish_Sparse (Output) then
         Files.Io_Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      --  Through the descriptor that wrote it, before its metadata is set:
      --  no reopening, which a read-only copy would refuse on Windows.
      if Walk.Durable
        and then Hostkit.Durability."=" (Files.Durability.Sync_Descriptor (Integer (Output), Destination_Path),
                                          Hostkit.Durability.Failed)
      then
         Files.Io_Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      GNAT.OS_Lib.Close (Output, Closed);
      Output := GNAT.OS_Lib.Invalid_FD;
      if not Closed then
         --  A network or quota-limited filesystem may report a full disk
         --  only here.
         Files.Io_Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      if Wants_Digest or else Track_Hard_Link then
         Digest := CryptoLib.Hashes.Finalize (Digest_Context);
         for Index in Digest'Range loop
            Digest_Text ((Index - Digest'First) * 2 + 1) :=
              Hex (Natural (Digest (Index)) / 16 + 1);
            Digest_Text ((Index - Digest'First) * 2 + 2) :=
              Hex (Natural (Digest (Index)) mod 16 + 1);
         end loop;
         Copied_Bytes_Digest := To_Unbounded_String (Digest_Text);
         if Wants_Digest then
            Walk.Root_Digest := Copied_Bytes_Digest;
         end if;
      end if;
      Check_Cancelled (Walk);
   exception
      when others =>
         if Input_Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Input_Descriptor);
         end if;
         if Output /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Output);
         end if;
         raise;
   end Copy_File_Bytes;

   procedure Copy_Node
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural;
      Walk             : in out Copy_Walk)
   is
      Times                  : Source_Time_Maps.Map renames Walk.Times;
      Preserve_Ownership     : Boolean renames Walk.Preserve_Ownership;
      Copied_Files           : Copied_File_Maps.Map renames Walk.Copied_Files;
      --  Only the root's own bytes are digested.
      Wants_Digest           : constant Boolean := Walk.Want_Root_Digest and then Depth = 0;
      --  A copy of a folder that (directly or transitively) contains a symlink to
      --  an ancestor would, without this cap, recurse until the path exceeds
      --  PATH_MAX. The symlink guard below removes that cause; this is a defensive
      --  backstop far beyond any real directory nesting. Reaching it raises, which
      --  fails the whole copy (see the function wrapper) rather than silently
      --  truncating -- important because a cross-device MOVE deletes the source
      --  only after a successful copy.
      Max_Copy_Depth : constant := 1024;

      State     : Node_State;
      Owned     : Boolean renames State.Owned;

      Metadata : Hostkit.Metadata_Copy.Snapshot := Hostkit.Metadata_Copy.No_Snapshot;
      Source_Identity : Files.Types.UString renames State.Source_Identity;
      Source_Revision : Files.Types.UString renames State.Source_Revision;
      Source_Content_Digest : Files.Types.UString;
      Track_Hard_Link : Boolean renames State.Track_Hard_Link;
      Copied_Bytes_Digest : Files.Types.UString renames State.Copied_Digest;

      procedure Copy_Metadata is
         --  Null but in the test suite (Files.File_System.Testing).
         Hook : constant Copy_Hook := After_Metadata;
      begin
         if not Hostkit.Metadata_Copy.Apply
           (Metadata, Destination_Path, Preserve_Ownership)
         then
            raise Ada.Directories.Use_Error;
         end if;
         Metadata := Hostkit.Metadata_Copy.No_Snapshot;
         if Hook /= null then
            Hook (Destination_Path);
         end if;
      end Copy_Metadata;

      procedure Record_Hard_Link is
      begin
         if Track_Hard_Link then
            --  The source as copied, checked once more against change during
            --  the copy (these revisions leave out the change time, which the
            --  link count moves). A regular file was hashed as it was copied,
            --  and the destination holds exactly those bytes; a link's target
            --  is short and read on both sides.
            declare
               From_Copy : constant Boolean := Length (Copied_Bytes_Digest) > 0;
            begin
               Source_Content_Digest :=
                 (if From_Copy then Copied_Bytes_Digest else To_Unbounded_String (Content_Digest (Source_Path, Walk)));
               if Files.File_Identities.Revision (Source_Path, False) /= To_String (Source_Revision)
                 or else (From_Copy and then Content_Digest (Source_Path, Walk) /= To_String (Source_Content_Digest))
                 or else (not From_Copy
                          and then Content_Digest (Destination_Path, Walk) /= To_String (Source_Content_Digest))
               then
                  raise Ada.Directories.Use_Error;
               end if;
            end;
            declare
               Identity : constant String := Files.File_Identities.Token (Destination_Path);
               Destination_Revision : constant String :=
                 Files.File_Identities.Revision (Destination_Path, False);
            begin
               if Identity = "" or else Destination_Revision = "" then
                  raise Ada.Directories.Use_Error;
               end if;
               Copied_Files.Insert
                 (To_String (Source_Identity),
                  (Path                 => To_Unbounded_String (Destination_Path),
                   Identity             => To_Unbounded_String (Identity),
                   Source_Revision      => Source_Revision,
                   Destination_Revision => To_Unbounded_String (Destination_Revision),
                   Content_Digest       => Source_Content_Digest));
            end;
         end if;
      end Record_Hard_Link;

      procedure Copy_Entry (Name : String) is
      begin
         Copy_Node (Hostkit.Fs.Join (Source_Path, Name), Hostkit.Fs.Join (Destination_Path, Name), Depth + 1, Walk);
      end Copy_Entry;

   begin
      Check_Cancelled (Walk);
      if Wants_Digest then
         Walk.Root_Digest := Null_Unbounded_String;
      end if;
      --  Capture before reading bytes or enumerating children changes atime.
      declare
      begin
         Metadata := Hostkit.Metadata_Copy.Capture (Source_Path);
         if not Hostkit.Metadata_Copy.Is_Available (Metadata) then
            raise Ada.Directories.Use_Error;
         end if;
         if Times.Contains (Source_Path) then
            declare
               Saved_Times : constant Copy_Times := Times.Element (Source_Path);
            begin
               Hostkit.Metadata_Copy.Set_Times (Metadata, Saved_Times);
            end;
         end if;
      end;
      --  Preserve a symlink as a link instead of following it. Ada.Directories.Kind
      --  dereferences links, so classifying by it would copy the link's *target*
      --  (losing the link, or -- for a link to an ancestor -- exploding into an
      --  unbounded recursive copy). Recreate the link verbatim and stop. This
      --  mirrors the search/size walkers, which also skip links via Hostkit.Fs.
      if Hostkit.Fs.Is_Link (Source_Path)
        or else Files.Fs_Primitives.Kind (Source_Path) = Ada.Directories.Ordinary_File
      then
         if Copy_Hard_Link (Source_Path, Destination_Path, Walk, Metadata, Wants_Digest, State) then
            return;
         end if;
      end if;
      if Hostkit.Fs.Is_Link (Source_Path) then
         declare
            Target  : Ada.Strings.Unbounded.Unbounded_String;
            Created : Boolean := False;
         begin
            if Hostkit.Fs.Read_Link_Target (Source_Path, Target) then
               Files.Io_Errors.Clear_Os_Error;
               Created := Hostkit.Fs.Create_Link (To_String (Target), Destination_Path);
               if not Created then
                  Files.Io_Errors.Capture;
               end if;
            end if;

            --  If the link cannot be recreated (unreadable target, or a host
            --  that refuses link creation, e.g. Windows without the privilege),
            --  raise rather than silently omit it. Copy_Tree is the copy step of
            --  the cross-device MOVE fallback, which deletes the source only
            --  after it returns: silently dropping the link and then deleting
            --  the original would lose it. Raising aborts the copy so the move
            --  keeps the source; the function wrapper maps this to
            --  error.copy.failed.
            if not Created then
               raise Program_Error;
            end if;
            Owned := True;
         end;
         Copy_Metadata;
         Record_Hard_Link;
         return;
      end if;

      if Depth > Max_Copy_Depth then
         --  Backstop only; the message would be caught and mapped to
         --  error.copy.failed by the function wrapper, never shown to the user.
         raise Program_Error;
      end if;

      case Files.Fs_Primitives.Kind (Source_Path) is
         when Ada.Directories.Directory =>
            begin
               Files.Io_Errors.Clear_Os_Error;
               Files.Fs_Primitives.Create_Directory (Destination_Path);
            exception
               when others =>
                  Files.Io_Errors.Capture;
                  raise;
            end;
            Owned := True;
            For_Each_Entry (Source_Path, Copy_Entry'Access);
         when Ada.Directories.Ordinary_File =>
            Copy_File_Bytes
              (Source_Path, Destination_Path, Walk, Wants_Digest, Hostkit.Metadata_Copy.Is_Encrypted (Metadata), State);
         when Ada.Directories.Special_File =>
            --  Opening a FIFO or device can block without a cancellation point.
            raise Ada.Directories.Use_Error;
      end case;
      Check_Cancelled (Walk);
      --  Apply attributes and times after children have been copied.
      --  Metadata failure aborts staging, so a move never discards its source.
      Copy_Metadata;
      Record_Hard_Link;
   exception
      when others =>
         Metadata := Hostkit.Metadata_Copy.No_Snapshot;
         if Owned then
            begin
               Delete_Owned_Tree (Destination_Path);
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
            end;
         end if;
         raise;
   end Copy_Node;

   procedure Copy_Tree
     (Source_Path : String;
      Destination_Path : String;
      Depth : Natural := 0;
      Cancel : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session) is
      Walk : Copy_Walk :=
        (Cancel                 => Cancel,
         Check_Job_Cancellation => Check_Job_Cancellation,
         Times                  => Times,
         Preserve_Ownership     => Preserve_Ownership,
         Copied_Files           => Load_Links (Batch),
         Shared_Batch           => Files.Copy_Context.Directory (Batch) /= "",
         others                 => <>);
   begin
      Check_Copy_Destination (Source_Path, Destination_Path);
      Copy_Node_Deep (Source_Path, Destination_Path, Depth, Walk);
      Save_Links (Batch, Walk.Copied_Files, Destination_Path, Destination_Path);
   end Copy_Tree;

   procedure Delete_Tree (Path : String) is
   begin
      --  Descriptor-relative and never following a link, on every host built
      --  for. A host without it (Tree_Delete_Unsupported) refuses rather than
      --  fall back to a pathname walk that a swapped-in link could redirect.
      if Hostkit.Fs."/=" (Hostkit.Fs.Delete_Tree_No_Follow (Path), Hostkit.Fs.Tree_Deleted) then
         raise Ada.Directories.Use_Error;
      end if;
   end Delete_Tree;

   procedure Delete_Owned_Tree (Path : String) is
      procedure Delete_Owned_Level (Path : String);

      procedure Delete_Root is
      begin
         Delete_Owned_Level (Path);
      end Delete_Root;

      procedure Delete_Owned_Level (Path : String) is
         Available : Boolean;
         Mode : Natural;
         Lease_Present  : Boolean := False;
         Marker_Present : Boolean := False;
         procedure Delete_Entry (Name : String) is
         begin
            if Name = Files.Protocol_Names.Transport_Lease then
               Lease_Present := True;
            elsif Name = Files.Protocol_Names.Transport_Marker then
               Marker_Present := True;
            else
               Delete_Owned_Level (Hostkit.Fs.Join (Path, Name));
            end if;
         end Delete_Entry;
      begin
         if Hostkit.Fs.Is_Link (Path) or else Files.Fs_Primitives.Kind (Path) /= Ada.Directories.Directory then
            Delete_Tree (Path);
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
         --  Keep the lease and the transport marker until every other child is
         --  gone. If one cannot be removed (a Windows sharing violation, EACCES),
         --  the restored directory still carries its marker and stays
         --  reclaimable; without it, cleanup and the scavenger refuse it forever.
         if Marker_Present then
            Delete_Owned_Level (Hostkit.Fs.Join (Path, Files.Protocol_Names.Transport_Marker));
         end if;
         if Lease_Present then
            Delete_Owned_Level (Hostkit.Fs.Join (Path, Files.Protocol_Names.Transport_Lease));
         end if;
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
