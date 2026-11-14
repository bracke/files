--  Test-only entry points into the trash backends (the application moves
--  items with Files.File_System.Move_To_Trash, which picks the backend itself)
--  and summaries of what the program reports, which only the suite reads.
package Files.File_System.Testing is

   --  Build the native trash request that would be needed for Path.
   --
   --  @param Path Filesystem path requested for native trash handling.
   --  @return Native trash request metadata.
   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request;

   --  Make the desktop's own trash refuse every item from now on (Refuse
   --  True), as an unreachable Recycle Bin would, or take items again
   --  (False). Nothing is attempted while it refuses.
   --
   --  @param Refuse Whether the native trash refuses.
   procedure Refuse_Native_Trash (Refuse : Boolean);

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

   --  From now on, hold every recovery-registry sweep just before it works
   --  on a payload (after it has let the registry lock go), as a slow trash
   --  move would, until Resume_Sweep_Work; at most 30 seconds each.
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

   --  Execute a trash request through the selected backend when supported.
   --
   --  @param Request Native trash request metadata.
   --  @return Trash execution result with adapter diagnostics.
   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   type Trash_Capabilities is record
      Backend             : Trash_Backend := Trash_Unavailable;
      Native_Platform     : Boolean := False;
      Xdg_Compatible      : Boolean := False;
      Metadata_Sidecar    : Boolean := False;
      Collision_Safe_Name : Boolean := False;
      Permanent_Delete    : Boolean := False;
   end record;

   type Root_Discovery_Diagnostics is record
      Root_Count              : Natural := 0;
      Ready_Count             : Natural := 0;
      Removable_Count         : Natural := 0;
      Windows_Drive_Count     : Natural := 0;
      Mount_Count             : Natural := 0;
      User_Mount_Count        : Natural := 0;
      Network_Mount_Count     : Natural := 0;
   end record;

   --  Return available filesystem root locations in deterministic order.
   --
   --  @return Root paths available on the host platform.
   function Available_Roots return Files.Types.String_Vectors.Vector;

   --  Return diagnostics for root discovery without changing the root list.
   --
   --  @return Root discovery counts and policy flags.
   function Root_Discovery_Status return Root_Discovery_Diagnostics;

   --  Return trash backend capabilities for the current environment.
   --
   --  @return Structured trash capability description.
   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities;

   --  Whether a mount point is one a user put there (a stick, a share), as
   --  the root list shows them: "/" and anything under /mnt, /media,
   --  /run/media, /Volumes, /System/Volumes or the session's gvfs directory,
   --  but not those containers themselves.
   --
   --  @param Mount_Point Absolute mount point.
   --  @param Runtime_Gvfs The session's gvfs directory, or "" when none.
   --  @return True when the mount is listed as a root.
   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean;

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

   --  Return the trash backend selected for the current environment.
   --
   --  @return Backend that Move_To_Trash will use, or Trash_Unavailable.
   function Trash_Backend_Of_Current_Environment return Trash_Backend;

   --  Evaluate native trash support for Request without deleting anything.
   --
   --  @param Request Native trash request metadata.
   --  @return Native trash support result.
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  Hand Request's item to the desktop's own trash (the Windows Recycle Bin
   --  or the macOS Trash). Nothing is attempted on a build that does not
   --  target that desktop.
   --
   --  @param Request Native trash request for a native backend.
   --  @return The evaluation, with Attempted and Completed set by the attempt.
   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     with Pre => Request.Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native;

   --  Format a timestamp for freedesktop trashinfo DeletionDate metadata.
   --
   --  @param Value Time value to format.
   --  @return Local timestamp in YYYY-MM-DDTHH:MM:SS form.
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String;

end Files.File_System.Testing;
