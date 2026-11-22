with Ada.Containers.Indefinite_Ordered_Maps;
with Files.File_System.Support;

--  The copy engine of Files.File_System. A private child: copying an entry
--  privately into a stage, checking it against its source, and publishing
--  it atomically without replacing anything (Copy_To_New_Path,
--  Publish_From_Stage), with the hard-link journal a batch of copies
--  shares. Files.File_System.Transfer is its public face.
private package Files.File_System.Copying is

   --  How Publish_From_Stage puts the entry on the device: not itself (a
   --  copy whose caller syncs it, Sync_Copy, or needs no flush), or the
   --  staged tree before it is published and its new folder after.
   type Publish_Flush is (No_Flush, Flush_Tree_And_Folder);

   --  The one publication of a staged entry, in this order: its intent is
   --  named (Files.Jobs.Context.Intend_Created), so a helper stopped after
   --  the move still has it found for Undo; it is moved to Target without
   --  replacing anything; it is given the access its new folder hands down
   --  (Inherit_Destination_Access) and, when that changed its revision,
   --  named again with the new one; and it is recorded
   --  (Files.Jobs.Context.Record_Created). With Flush_Tree_And_Folder the
   --  staged tree is synced first, and Target's folder last: a failure of
   --  that last sync is traced, not returned, as the entry is published and
   --  recorded whatever it answers.
   --  @param Staged The staged entry.
   --  @param Target Where it is published; must not exist.
   --  @param Source What it was copied from, or empty (an archive, an
   --    extraction).
   --  @param Identity The staged entry's identity, which the move keeps.
   --  @param Revision Its revision in staging; on return the revision it
   --    was recorded with.
   --  @param Flush Whether this syncs the tree and the folder.
   --  @return False when the tree could not be synced or the move was
   --    refused: nothing is published then, and the caller decides whether
   --    that raises.
   function Publish_From_Stage
     (Staged, Target, Source, Identity : String;
      Revision                         : in out Files.Types.UString;
      Flush                            : Publish_Flush) return Boolean;

   --  What a copy is for: a plain copy, or the copy a move makes before it
   --  removes the source. A move's copy must keep the source's owner before
   --  it is published, and flushes each file to the device as it writes it
   --  (Sync_Copy then needs only the folders).
   type Copy_Purpose is (For_Copy, For_Move);

   type Copied_File is record
      Path, Identity, Source_Revision, Destination_Revision, Content_Digest : Files.Types.UString;
   end record;
   package Copied_File_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Copied_File);

   --  Copy privately and publish atomically without replacing an existing entry.
   --  @param Source_Path Source file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Purpose A plain copy, or a move's (see Copy_Purpose).
   --  @param Batch Shared journal for hard links across copied roots.
   procedure Copy_To_New_Path
     (Source_Path : String; Destination_Path : String; Cancel : Cancellation_Check := Job_Cancelled;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session);

   --  @param Source_Path Source file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Identity Identity captured before publishing the new destination.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Purpose A plain copy, or a move's (see Copy_Purpose).
   --  @param Batch Shared journal for hard links across copied roots.
   --  @param Times Source times captured before a move's verification traversal.
   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity : out Files.Types.UString;
      Cancel : Cancellation_Check := Job_Cancelled;
      Times : Support.Source_Time_Maps.Map := Support.Source_Time_Maps.Empty_Map;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session);

   --  Copy and return identity plus a directory or regular-file revision.
   --  @param Source_Path Existing file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Identity Identity captured in private staging before publication.
   --  @param Tree_Revision_Value Stable revision captured before publication; empty for links.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Times Source times captured before verification reads the source.
   --  @param Purpose A plain copy, or a move's (see Copy_Purpose).
   --  @param Batch Shared journal for hard links across copied roots.
   --  @param Root_Digest When given, set to the SHA-256 of the bytes copied
   --    for a regular-file root, as read during the copy; empty otherwise.
   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Cancel : Cancellation_Check := Job_Cancelled;
      Times : Support.Source_Time_Maps.Map := Support.Source_Time_Maps.Empty_Map;
      Purpose : Copy_Purpose := For_Copy;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session;
      Root_Digest : access Files.Types.UString := null);

end Files.File_System.Copying;
