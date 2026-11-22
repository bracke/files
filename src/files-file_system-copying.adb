with Hostkit.Fs;
with Hostkit.Metadata_Copy;
with Files.IO.Fs_Primitives;
with Files.Protocol_Names;
with Interfaces;
with Ada.Streams;
with Files.Diagnostics;
with Ada.Directories;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Jobs.Context;
with Files.File_Identities;
with Files.IO.Errors;
with CryptoLib.Hashes;
with Files.File_System.Digests;
with Files.IO.Durability;
with Hostkit.Durability;
with Hostkit.Metadata;
with Hostkit.Regular_Files;

package body Files.File_System.Copying is

   use Files.File_System.Support;

   --  The entry a copy stage holds before it is published.
   Payload_Name : String renames Files.Protocol_Names.Stage_Payload;

   --  @param Batch Batch journal to load.
   --  @return Verified source-to-destination records for this batch.
   function Load_Links (Batch : Files.Jobs.Copy_Context.Session) return Copied_File_Maps.Map;

   --  @param Batch Batch journal to update.
   --  @param Links Source identity records, including this newly published root.
   --  @param Stage Private payload prefix to replace after publication.
   --  @param Destination Published payload prefix.
   procedure Save_Links
     (Batch : Files.Jobs.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String);

   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_64;

   procedure Check_Copy_Destination (Source, Destination : String) is
   begin
      if Hostkit.Fs.Is_Link (Source) or else Files.IO.Fs_Primitives.Kind (Source) /= Ada.Directories.Directory then
         return;
      end if;
      declare
         --  Links resolved, on Windows too: a copy into its own tree reached
         --  through a link or junction is still a copy into its own tree.
         Original : constant String := Files.IO.Fs_Primitives.Real_Name (Source);
         Identity : constant String := Files.File_Identities.Token (Source);
         Parent : UString := To_Unbounded_String
           (Files.IO.Fs_Primitives.Real_Name (Files.IO.Fs_Primitives.Parent_Directory (Destination)));
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
                 Files.IO.Fs_Primitives.Real_Name (Hostkit.Fs.Join (To_String (Parent), ".."));
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

   function Load_Links (Batch : Files.Jobs.Copy_Context.Session) return Copied_File_Maps.Map is
      Items : constant Files.Types.String_Vectors.Vector := Files.Jobs.Copy_Context.Records (Batch);
      Links : Copied_File_Maps.Map;
   begin
      --  Copy_Context is deliberately only a bounded transport.  Validate
      --  the hard-link schema here before a persisted pathname can be used
      --  for identity checks, digest reads, or link creation.
      if not Files.Jobs.Copy_Context.Valid (Items) then
         raise Ada.Directories.Use_Error;
      end if;
      for Position in 1 .. Files.Jobs.Copy_Context.Record_Count (Items) loop
         declare
            Item : constant Files.Jobs.Copy_Context.Copy_Record := Files.Jobs.Copy_Context.Decode (Items, Position);
         begin
            Links.Insert
              (To_String (Item.Source_Identity),
               (Path                 => Item.Destination_Path,
                Identity             => Item.Destination_Identity,
                Source_Revision      => Item.Source_Revision,
                Destination_Revision => Item.Destination_Revision,
                Content_Digest       => Item.Content_Digest));
         end;
      end loop;
      return Links;
   end Load_Links;

   procedure Save_Links
     (Batch : Files.Jobs.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String) is
      Items : Files.Types.String_Vectors.Vector;
   begin
      for Cursor in Links.Iterate loop
         declare
            Item : constant Copied_File := Copied_File_Maps.Element (Cursor);
         begin
            Files.Jobs.Copy_Context.Encode
              ((Source_Identity      => To_Unbounded_String (Copied_File_Maps.Key (Cursor)),
                Source_Revision      => Item.Source_Revision,
                Content_Digest       => Item.Content_Digest,
                Destination_Path     =>
                  To_Unbounded_String (Hostkit.Fs.Rebase (To_String (Item.Path), Stage, Destination)),
                Destination_Identity => Item.Identity,
                Destination_Revision => Item.Destination_Revision),
               Items);
         end;
      end loop;
      Files.Jobs.Copy_Context.Save (Batch, Items);
   end Save_Links;

   --  What one copy walk carries through every level of the tree: how it
   --  is stopped, what it keeps, what it shares, and what it reports.
   type Copy_Walk is limited record
      Cancel                 : Cancellation_Check := Job_Cancelled;
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
     (Source_Path : String; Destination_Path : String; Cancel : Cancellation_Check := Job_Cancelled;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session) is
      Identity : Files.Types.UString;
   begin
      Copy_To_New_Path (Source_Path, Destination_Path, Identity, Cancel,
                        Purpose => Purpose, Batch => Batch);
   end Copy_To_New_Path;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity : out Files.Types.UString;
      Cancel : Cancellation_Check := Job_Cancelled;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   is
      Tree_Revision_Value : Files.Types.UString;
   begin
      Copy_To_New_Path
        (Source_Path, Destination_Path, Identity, Tree_Revision_Value, Cancel, Times,
         Purpose, Batch);
   end Copy_To_New_Path;

   --  Give an entry just published from its private stage (a copy, or what
   --  Compress or Extract made) the access its new folder hands down, and
   --  its revision afresh where that changed it. The entry is already
   --  published, so nothing here raises: a caller must still record it.
   --  Cancellation is no longer heeded (the work is done), and a failure
   --  keeps the revision it was published with.
   --  @param Path The published entry.
   --  @param Revision Its revision at publication; read again for a folder
   --    where inheriting wrote the change times it reads (Windows:
   --    Hostkit.Metadata.Inherit_Rewrites_Change_Times).
   procedure Inherit_Destination_Access
     (Path     : String;
      Revision : in out Files.Types.UString)
   is
      Published : constant Files.Types.UString := Revision;
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
      if Hostkit.Metadata.Inherit_Rewrites_Change_Times
        and then not Hostkit.Fs.Is_Link (Path)
        and then Files.IO.Fs_Primitives.Kind (Path) = Ada.Directories.Directory
      then
         declare
            Fresh : constant String := Tree_Revision_Of (Path, Cancel => null);
         begin
            if Fresh /= "" then
               Revision := To_Unbounded_String (Fresh);
            end if;
         end;
      end if;
   exception
      when Failure : others =>
         --  A concurrent change (or anything else) while re-reading: the
         --  copy stays published and recorded with its pre-inherit revision.
         Files.Diagnostics.Note (Failure, "Files.File_System.Support");
         Revision := Published;
   end Inherit_Destination_Access;

   function Publish_From_Stage
     (Staged, Target, Source, Identity : String;
      Revision                         : in out Files.Types.UString;
      Flush                            : Publish_Flush) return Boolean
   is
      use type Hostkit.Durability.Outcome;
      Staged_Revision : constant String := To_String (Revision);
   begin
      if Flush = Flush_Tree_And_Folder and then Files.IO.Durability.Sync_Tree (Staged) = Hostkit.Durability.Failed then
         return False;
      end if;
      Files.Jobs.Context.Intend_Created (Target, Source, Identity, Staged_Revision);
      if not Move_No_Replace (Staged, Target) then
         return False;
      end if;
      Inherit_Destination_Access (Target, Revision);
      --  A helper stopped before the record below still has the entry found
      --  with the revision it has now, not the one its first intent named.
      if To_String (Revision) /= Staged_Revision then
         Files.Jobs.Context.Intend_Created (Target, Source, Identity, To_String (Revision));
      end if;
      Files.Jobs.Context.Record_Created (Target, Source, Identity, To_String (Revision));
      --  The new name on the device. The entry is published and recorded
      --  whatever this answers, as Durable_Writes.Publish's callers take a
      --  Published_Not_Durable write: its contents are on the device, only
      --  the name may be lost to a crash. The failure is traced.
      if Flush = Flush_Tree_And_Folder
        and then Files.IO.Durability.Sync_Directory (Files.IO.Fs_Primitives.Parent_Directory (Target))
          = Hostkit.Durability.Failed
      then
         Files.Diagnostics.Trace ("Files.File_System", "published_not_durable=" & Target);
      end if;
      return True;
   end Publish_From_Stage;

   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Cancel : Cancellation_Check := Job_Cancelled;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session;
      Root_Digest : access Files.Types.UString := null)
   is
      Stage : UString;
      Walk  : Copy_Walk :=
        (Cancel                 => Cancel,
         Times                  => Times,
         Preserve_Ownership     => Purpose = For_Move,
         Copied_Files           => Load_Links (Batch),
         Shared_Batch           => Files.Jobs.Copy_Context.Directory (Batch) /= "",
         Durable                => Purpose = For_Move,
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
      Stage := To_Unbounded_String (Create_Stage (Files.IO.Fs_Primitives.Parent_Directory (Destination_Path)));
      Copy_Node_Deep (Source_Path, Hostkit.Fs.Join (To_String (Stage), Payload_Name), 0, Walk);
      Identity := To_Unbounded_String (Files.File_Identities.Token (Hostkit.Fs.Join (To_String (Stage), Payload_Name)));
      if Root_Digest /= null then
         Root_Digest.all := Copied_Digest;
      end if;
      declare
         Payload : constant String := Hostkit.Fs.Join (To_String (Stage), Payload_Name);
      begin
         if not Hostkit.Fs.Is_Link (Payload)
           and then Files.IO.Fs_Primitives.Kind (Payload) = Ada.Directories.Ordinary_File
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
            Tree_Revision_Value := To_Unbounded_String (Tree_Revision_Of (Payload, Cancel));
         end if;
      end;
      --  Never publish an unidentifiable payload: Undo and crash recovery
      --  could not verify it afterward, even if staging succeeded.
      if Length (Identity) = 0
        or else (not Hostkit.Fs.Is_Link (Hostkit.Fs.Join (To_String (Stage), Payload_Name))
          and then Length (Tree_Revision_Value) = 0)
      then
         raise Ada.Directories.Use_Error;
      end if;
      --  The walk flushed what a move needs (Durable); a move's caller
      --  syncs the published copy (Sync_Copy) before it removes the source.
      if not Publish_From_Stage
        (Hostkit.Fs.Join (To_String (Stage), Payload_Name), Destination_Path, Source_Path, To_String (Identity),
         Tree_Revision_Value, No_Flush)
      then
         raise Ada.Directories.Use_Error;
      end if;
      --  Only a published copy is a link target for the rest of the batch: a
      --  journal naming a destination the publish refused would make a later
      --  hard link to the same file fail its identity check instead of being
      --  copied. A crash between the two, or a journal the disk refuses now,
      --  only costs a later copy instead of a link: the published copy stands.
      begin
         Save_Links (Batch, Walk.Copied_Files, Hostkit.Fs.Join (To_String (Stage), Payload_Name), Destination_Path);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Support");
      end;
      --  Publication is complete; leftover staging must not falsify its result.
      declare
         Removed : constant Boolean := Files.Jobs.Context.Discard_Stage (To_String (Stage));
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
                  Removed : constant Boolean := Files.Jobs.Context.Discard_Stage (To_String (Stage));
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

   --  Stop a copy the user or the job cancelled.
   procedure Check_Cancelled (Walk : Copy_Walk) is
   begin
      if Walk.Cancel /= null and then Walk.Cancel.all then
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
            Add (Files.File_System.Digests.To_Bytes (To_String (Target)));
         end;
      else
         --  Use the descriptor-pinned, no-follow regular-file reader.  A
         --  pathname open after the classification above could otherwise
         --  follow a replacement symlink or block on a replacement FIFO.
         return Regular_File_Digest
           (Path, Walk.Cancel);
      end if;
      Digest := CryptoLib.Hashes.Finalize (Context);
      return Files.File_System.Digests.Hex (Digest);
   end Content_Digest;

   --  Make Destination a hard link to the copy of Source's inode already made
   --  in this walk, after checking neither changed since.
   --
   --  @return False when Source is not an inode the walk copied before, or
   --  that copy or the source changed since (Destination is then copied).
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
            --  When either moved, a link would carry the wrong bytes: this
            --  name gets a copy of its own instead, which then stands for the
            --  inode in the rest of the walk (Record_Hard_Link replaces it).
            if Files.File_Identities.Revision (Source_Path, False) /= To_String (First.Source_Revision)
              or else Content_Digest (Source_Path, Walk) /= To_String (First.Content_Digest)
              or else Files.File_Identities.Token (To_String (First.Path)) /= To_String (First.Identity)
              or else Files.File_Identities.Revision (To_String (First.Path), False)
                /= To_String (First.Destination_Revision)
              or else Content_Digest (To_String (First.Path), Walk) /= To_String (First.Content_Digest)
            then
               State.Track_Hard_Link := True;
               return False;
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
      Buffer : Stream_Element_Array (1 .. Files.Types.IO_Chunk_Bytes);
      Last   : Stream_Element_Offset;
      Next   : Stream_Element_Offset;
      Bytes_Read : Integer;
      Wrote  : Integer;
      Closed : Boolean;
      Sparse : Boolean := False;
      Digest_Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
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
               Files.IO.Errors.Capture;
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
            Files.IO.Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
      end;
      --  0666 less the creation mask, as GNAT's Create_New_File makes it.
      Output := Hostkit.Regular_Files.Create_New (Destination_Path, 8#666#, Encrypted);
      if Output = GNAT.OS_Lib.Invalid_FD then
         Files.IO.Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      State.Owned := True;
      loop
         Check_Cancelled (Walk);
         Bytes_Read := GNAT.OS_Lib.Read
           (Input_Descriptor, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0 then
            Files.IO.Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
         exit when Bytes_Read = 0;
         Last := Buffer'First + Stream_Element_Offset (Bytes_Read) - 1;
         Copy_Buffer (Last);
      end loop;
      GNAT.OS_Lib.Close (Input_Descriptor);
      Input_Descriptor := GNAT.OS_Lib.Invalid_FD;
      --  No reason left over from an earlier call: a flush or sync that
      --  fails without setting errno records nothing stale.
      Files.IO.Errors.Clear_Os_Error;
      if Sparse and then not Hostkit.Regular_Files.Finish_Sparse (Output) then
         Files.IO.Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      --  Through the descriptor that wrote it, before its metadata is set:
      --  no reopening, which a read-only copy would refuse on Windows.
      Files.IO.Errors.Clear_Os_Error;
      if Walk.Durable
        and then Hostkit.Durability."=" (Files.IO.Durability.Sync_Descriptor (Integer (Output), Destination_Path),
                                          Hostkit.Durability.Failed)
      then
         Files.IO.Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      GNAT.OS_Lib.Close (Output, Closed);
      Output := GNAT.OS_Lib.Invalid_FD;
      if not Closed then
         --  A network or quota-limited filesystem may report a full disk
         --  only here.
         Files.IO.Errors.Capture;
         raise Ada.Directories.Use_Error;
      end if;
      if Wants_Digest or else Track_Hard_Link then
         Digest := CryptoLib.Hashes.Finalize (Digest_Context);
         Copied_Bytes_Digest := To_Unbounded_String (Files.File_System.Digests.Hex (Digest));
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
   is separate;

end Files.File_System.Copying;
