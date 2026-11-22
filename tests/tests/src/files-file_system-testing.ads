--  Test-only hooks into Files.File_System's private part (copies, restores,
--  deletes, sweeps) and the helpers the suite drives them with. The
--  children's own hooks are in their Testing children (Trash.Testing,
--  Transfer.Testing, Permissions.Testing, Roots.Testing).
package Files.File_System.Testing is

   --  How Change_Source_After_Copy changes a source once it is copied:
   --  Edit_Source writes "new edits" over the source file; Replace_Source
   --  renames it to Source & ".saved" and makes a new file holding "new
   --  edits" at its name; Edit_Folder_Child writes "new edits" over the
   --  source folder's "child".
   type Source_Change is (Edit_Source, Replace_Source, Edit_Folder_Child);

   --  Change Source, once, as an editor saving at that moment would: the
   --  first time a copy has set the metadata of an entry whose path starts
   --  with Trigger and ends with "/payload" -- the copy is complete, and
   --  the source not yet checked against it. Arming it again rearms it.
   --
   --  @param Trigger The start of the copy's path (separators compare as one).
   --  @param Source The source to change.
   --  @param Change How it changes.
   procedure Change_Source_After_Copy (Trigger, Source : String; Change : Source_Change);

   --  Change no source any more.
   procedure Stop_Changing_Source;

   --  From now on, refuse to give a read-only folder back its mode after a
   --  rename that leaves it at Trigger, as a failing chmod would. With a
   --  Block, the first refusal also makes a folder at Block holding a
   --  "replacement" file of "replacement bytes" -- something new at the
   --  original's name, which putting the original back must not replace.
   --
   --  @param Trigger The folder's path after the rename (separators compare as one).
   --  @param Block Where to make the replacement folder, or "" for none.
   procedure Fail_Directory_Restore (Trigger : String; Block : String := "");

   --  Give folders their modes back again.
   procedure Stop_Failing_Directory_Restore;

   --  From now on, refuse to delete the entry at Trigger inside a folder of
   --  ours, as a Windows sharing violation would.
   --
   --  @param Trigger The entry's path (separators compare as one).
   procedure Fail_Owned_Delete (Trigger : String);

   --  Delete entries of ours again.
   procedure Stop_Failing_Owned_Delete;

   --  From now on, make Creation_Matches refuse every entry (Refuse True),
   --  as if something had touched each one since its creation, so Undo can
   --  verify none; or verify them again (False).
   --
   --  @param Refuse Whether every creation is refused.
   procedure Refuse_Creation_Matches (Refuse : Boolean);

   --  From now on, have every hard link a copy asks for refused (Refuse
   --  True), as a destination that takes none (FAT, exFAT, many network
   --  mounts) would; or let the host answer again (False).
   --
   --  @param Refuse Whether every hard link is refused.
   procedure Refuse_Hard_Links (Refuse : Boolean);

   --  From now on, hold every recovery-registry sweep just before it works
   --  on a payload (after it has let the registry lock go), as a slow trash
   --  move would, until Resume_Sweep_Work; at most 120 seconds each, far
   --  above a test's wait for work that must not wait for the sweep.
   procedure Pause_Sweep_Work;

   --  @return Whether a sweep has reached the pause since Pause_Sweep_Work.
   function Sweep_Work_Paused return Boolean;

   --  Let held sweeps go on, and hold none any more.
   procedure Resume_Sweep_Work;

   --  Delete a folder of ours (a recovery stage, a transport) the way the
   --  program does.
   --
   --  @param Path The folder.
   procedure Delete_Owned_Tree (Path : String);

   --  Arm the faults the environment names, for a helper the suite started:
   --  FILES_TEST_TRASH_TRIGGER, FILES_TEST_TRASH_SOURCE and
   --  FILES_TEST_TRASH_FAULT ("edit", "replace" or "folder") as
   --  Change_Source_After_Copy; FILES_TEST_DIRECTORY_RESTORE_FAULT and
   --  FILES_TEST_DIRECTORY_RESTORE_BLOCK as Fail_Directory_Restore.
   procedure Install_From_Environment;

   --  Whether Name, the name of a file that already exists, can be stored in
   --  Directory: only what that filesystem cannot hold is refused -- empty,
   --  "." / "..", a separator or NUL on POSIX; Windows rules on a FAT, exFAT or
   --  NTFS destination (which cannot store invalid UTF-8 either). A name
   --  another program created ("notes " with a trailing space, bytes that are
   --  not UTF-8) copies and moves like any other; Valid_Leaf_Name_At, for
   --  names a user types, refuses those too.
   --
   --  @param Name Existing filename without parent path components.
   --  @param Directory The directory the name will live in.
   --  @return True when the destination can hold Name.
   function Storable_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean;

   --  Whether Child is Parent or lies inside it, as the program decides it
   --  (Path_Is_Within), with Folds standing in for the volumes: whether the
   --  one holding a folder folds names.
   --
   --  @param Child Candidate path.
   --  @param Parent Candidate ancestor.
   --  @param Folds Whether the volume holding a folder folds names.
   --  @return True when Child is Parent or lies inside it.
   function Path_Is_Within
     (Child, Parent : String;
      Folds         : not null access function (Directory : String) return Boolean)
      return Boolean;

   --  Move Source to the new path Destination by copy, as a cross-device
   --  move does (Files.File_System.Recovery.Move_By_Copy), refusing a
   --  Source whose identity is not Expected_Identity when it is copied.
   --
   --  @param Source Entry to move.
   --  @param Destination New pathname; never replaced.
   --  @param Expected_Identity The identity Source must have, or "".
   --  @return As Move_By_Copy, with "error.move.failed" for a failure
   --    with no more specific cause.
   function Move_By_Copy
     (Source, Destination : String;
      Expected_Identity   : String)
      return Mutation_Result;

end Files.File_System.Testing;
