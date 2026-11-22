with Ada.Containers.Indefinite_Ordered_Maps;
with Hostkit.Fs;
with Hostkit.Metadata_Copy;

--  The machinery Files.File_System's parent and concern children share. A
--  private child. It holds moving and removing entries (Move_No_Replace,
--  Sync_Copy, Delete_Owned_Tree) with the source snapshots that verify a
--  copy or move against its source (Snapshot, Same_Shape, Tree_Revision,
--  Weak_Change_Times); staging (Create_Stage); listing a folder
--  (For_Each_Entry); and where files keeps its own data
--  (Application_Data_Directory, the volume-trash list's path) and how an
--  environment variable is read. The copy engine itself is
--  Files.File_System.Copying.
private package Files.File_System.Support is
   use type Hostkit.Metadata_Copy.Entry_Times;

   --  Enumerate names without following links or dropping dangling links.
   --  Raises Use_Error before buffered names exceed the shared entry or byte
   --  budget, so a single hostile directory cannot exhaust process memory.
   --  @param Path Directory to read.
   --  @param Visit Called for each entry other than dot and dot-dot.
   procedure For_Each_Entry
     (Path : String; Visit : not null access procedure (Name : String));

   --  What Sync_Copy puts on the device: every file and folder of the copy,
   --  or its folders only.
   type Sync_Scope is (Files_And_Folders, Folders_Only);

   --  Put a just-published copy on the storage device: every regular file
   --  and directory in it (links are not followed), then the folder that
   --  holds it. A move removes its source only after this, so a crash of the
   --  machine cannot leave neither the source nor a whole copy. The source,
   --  not the copy, is listed to find the entries: listing a folder sets its
   --  access time, and the copy's are the source's, kept.
   --  @param Source What was copied, still in place.
   --  @param Destination Its published copy.
   --  @return False when any sync failed; a host that cannot sync
   --    directories (Not_Supported) does not count as a failure.
   --  @param Scope Folders_Only when the walk already flushed every file
   --    (a For_Move Copy_To_New_Path): then only the folders are synced.
   function Sync_Copy
     (Source, Destination : String;
      Scope               : Sync_Scope := Files_And_Folders) return Boolean;

   --  Whether environment variable Name equals Expected, compared
   --  case-insensitively.
   --
   --  @param Name Environment variable name.
   --  @param Expected Value to compare against.
   --  @return True when the variable's value equals Expected.
   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

   --  @param Parent Existing directory on the destination filesystem.
   --  @return Exclusively created, journaled private staging directory.
   function Create_Stage (Parent : String) return String;

   subtype Copy_Times is Hostkit.Metadata_Copy.Entry_Times;
   package Source_Time_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Copy_Times);

   type Source_Snapshot is record
      Root_Revision : Files.Types.UString;
      --  The root's identity token, as read when it was snapshotted.
      Root_Identity : Files.Types.UString;
      Entries : Files.Types.String_Vectors.Vector;
      --  Entries without their content digests, for Same_Shape.
      Shapes : Files.Types.String_Vectors.Vector;
      Times : Source_Time_Maps.Map;
      --  Whether every file's content was read (Weak_Change_Times held): a
      --  snapshot to compare with this one is taken by the same rule.
      Weak_Change_Times : Boolean := False;
   end record;

   --  Verification excludes access times changed by reading the source.
   --  @param Left Original identity and revision snapshot.
   --  @param Right Snapshot to compare with the original.
   --  @return True when identities and revisions match.
   overriding function "=" (Left, Right : Source_Snapshot) return Boolean;

   --  Move without replacement, restoring a read-only directory's owner mode.
   --  @param Source Source entry to rename.
   --  @param Destination New destination pathname.
   --  @return True when the rename succeeded; False leaves the source in place.
   function Move_No_Replace (Source, Destination : String) return Boolean;

   --  Move_No_Replace, saying why a refused rename failed.
   --  @param Source Source entry to rename.
   --  @param Destination New destination pathname.
   --  @return Moved when the rename succeeded. Only Move_Cross_Device and
   --          Move_Unsupported may be answered with a copy and delete.
   function Move_No_Replace_Outcome
     (Source, Destination : String)
      return Hostkit.Fs.Move_Outcome;

   --  @param Outcome A refused no-replace move.
   --  @return True when a copy and delete may stand in for the rename.
   function Copy_May_Replace_Move (Outcome : Hostkit.Fs.Move_Outcome) return Boolean is
     (Outcome in Hostkit.Fs.Move_Cross_Device | Hostkit.Fs.Move_Unsupported);

   --  Whether the change times of the filesystem holding Path cannot pin an
   --  edit: a DOS-family one (FAT, exFAT), where setting the modification
   --  time sets the change time too, or one that keeps whole seconds (HFS+,
   --  ext3), where an edit in the same second leaves the change time as it
   --  was. Snapshots there pin every file by content.
   --
   --  @param Path An existing entry on that filesystem.
   --  @return True when the change time is no proof of an unchanged file.
   function Weak_Change_Times (Path : String) return Boolean;

   --  Whether a snapshot trusts change times: decided from the root
   --  (Weak_Change_Times), or as an earlier snapshot it is compared with did.
   type Change_Time_Trust is (Decide_Change_Times, Trust_Change_Times, Distrust_Change_Times);

   --  The rule Snapshot followed for Taken, to take another by.
   --
   --  @param Taken An earlier snapshot.
   --  @return Its rule, as a choice for Snapshot.
   function Trust_Of (Taken : Source_Snapshot) return Change_Time_Trust is
     (if Taken.Weak_Change_Times then Distrust_Change_Times else Trust_Change_Times);

   --  A snapshot reads one file's content at most: a regular-file root's.
   --  Every entry below the root is pinned by its revision, change time
   --  included, which any write moves; only the root's change time is left
   --  out (the private rename that verifies a move changes it), so a root
   --  file is pinned by its content instead. Where Weak_Change_Times holds,
   --  every file's content is read.
   --
   --  @param Path Source tree to snapshot without following links.
   --  @param Content False to skip reading the root file's content: the
   --    result then supports only Same_Shape, a cheap early check before a
   --    full one, or With_Root_Content.
   --  @return Sorted identities, revisions, and the root file's content
   --    digest, raising if any entry cannot be verified.
   --  @param Cancel What stops it (Job_Cancelled), or null for recovery that
   --    must finish once the job is cancelled.
   --  @param Change_Times Decide whether change times are weak from Path,
   --    or take another snapshot by an earlier one's rule (Trust_Of).
   function Snapshot
     (Path                   : String;
      Content                : Boolean := True;
      Cancel                 : Cancellation_Check := Job_Cancelled;
      Change_Times           : Change_Time_Trust := Decide_Change_Times)
      return Source_Snapshot;

   --  Where files keeps its own data (the recovery index, the volume-trash
   --  list): the per-user application data directory, or FILES_TEST_TEMP's
   --  data folder under the test suite.
   --
   --  @return The directory, or "" when none can be named.
   function Application_Data_Directory return String;

   --  files' own folder in Application_Data_Directory
   --  (Protocol_Names.Data_Folder).
   --
   --  @return The folder, or "" when Application_Data_Directory has no name.
   function Files_Data_Directory return String;

   --  The list of remembered volume trashes in Files_Data_Directory
   --  (Protocol_Names.Volume_Trash_List).
   --
   --  @return The list's path, or "" when Files_Data_Directory has no name.
   function Volume_Trash_List_Path return String;

   --  A snapshot taken with Content => False, completed with the digest of a
   --  regular-file root obtained another way (as it was copied), so the root
   --  is not read just to hash it.
   --
   --  @param Snapshot Metadata-only snapshot.
   --  @param Digest The root file's content digest; empty leaves Snapshot as is.
   --  @return The snapshot Snapshot (Path) would have returned for that content.
   function With_Root_Content (Snapshot : Source_Snapshot; Digest : String) return Source_Snapshot;

   --  @param Left First snapshot.
   --  @param Right Second snapshot.
   --  @return True when identities and revisions (not contents) match.
   function Same_Shape (Left, Right : Source_Snapshot) return Boolean;

   --  @param Path Existing entry to inspect without following symbolic links.
   --  @return SHA-256 of a directory's recursive metadata and file contents;
   --    stable metadata and a SHA-256 content digest for a regular file; or
   --    empty for a link or unsupported or unreadable entry.
   --    Raises when a directory cannot be completely verified.
   function Tree_Revision (Path : String) return String;

   --  Remove a private or identity-verified owned copy, releasing directory
   --  write restrictions preserved from its source. Never follows symlinks.
   --  @param Path Private or identity-verified owned entry to remove.
   procedure Delete_Owned_Tree (Path : String);

   --  Run Work on a task whose stack holds a tree walk's full depth, and
   --  hand its failure and I/O error code back to the caller.
   --  @param Work The walk to run.
   procedure On_Large_Stack (Work : not null access procedure);

   --  @param Path Regular file to read.
   --  @param Cancel What stops it.
   --  @return SHA-256 of its content, as hex.
   function Regular_File_Digest
     (Path   : String;
      Cancel : Cancellation_Check := Job_Cancelled) return String;

   --  As Tree_Revision, optionally for recovery that must finish after
   --  cancellation.
   --
   --  @param Path Existing entry to inspect without following symbolic links.
   --  @param Cancel What stops it (Job_Cancelled), or null to keep going once
   --    the job is cancelled.
   --  @return As Tree_Revision.
   function Tree_Revision_Of (Path : String; Cancel : Cancellation_Check) return String;

end Files.File_System.Support;
