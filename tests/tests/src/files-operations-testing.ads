--  Test-only views of Files.Operations: how the suite classifies an open
--  action's result, which the program never asks.
package Files.Operations.Testing is

   type Open_Action_Lifecycle_State is
     (Open_Action_Not_Started,
      Open_Action_Preflight_Failed,
      Open_Action_Spawned,
      Open_Action_Completed,
      Open_Action_Failed);

   type Open_Action_Lifecycle is record
      State             : Open_Action_Lifecycle_State := Open_Action_Not_Started;
      Executable        : UString;
      Argument_Count    : Natural := 0;
      Uses_Shell        : Boolean := False;
      Exit_Status_Known : Boolean := False;
      Exit_Status       : Integer := 0;
      Cancellation_Available : Boolean := False;
   end record;

   --  Build lifecycle metadata for an operation result.
   --
   --  @param Result Operation result to summarize.
   --  @return Open-action lifecycle metadata.
   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle;

   --  Return the terminal-emulator executable that Open_Terminal would launch.
   --
   --  The TERMINAL environment variable is preferred on every host: it is the
   --  user naming the one they want. Otherwise the answer is the host's --
   --  the first of a list of common emulators found on PATH on Linux, of
   --  Windows Terminal, PowerShell and cmd on Windows, and `open` on macOS,
   --  where a terminal is an application bundle rather than a program on PATH.
   --  The result is empty when no terminal emulator is available.
   --
   --  @return Terminal executable name or path, or an empty string when none.
   function Detected_Terminal return String;

   --  Return whether Query occurs, case-insensitively, in the raw bytes Bytes.
   --
   --  This is the pure, filesystem-free match seam the content search uses on
   --  each file's bounded leading bytes. An empty Query never matches, and bytes
   --  classified as binary (via the Quick Look NUL/control heuristic) never match
   --  so binary files are skipped without further inspection.
   --
   --  @param Bytes Raw leading bytes of a file.
   --  @param Query Text to look for.
   --  @return True when Query occurs case-insensitively in textual Bytes.
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean;

   --  Prepare the selected file's open action without executing it.
   --
   --  Directories are reported as navigable targets, and regular files use
   --  settings-driven action lookup plus placeholder expansion.
   --
   --  @param Model Window model to inspect.
   --  @param Settings Settings model used for open-action lookup.
   --  @param Modifiers Active modifier keys for file open-action lookup.
   --  @return Structured operation result with expanded action data.
   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result;

   --  Apply New_Mode to the single selected item through chmod, recording the
   --  previous mode for undo and reloading so the info pane reflects the change.
   --
   --  The operation is disabled unless exactly one non-trash item is selected,
   --  its mode was read, and the platform supports permission changes.
   --
   --  @param Model Window model whose selected item's mode is changed.
   --  @param New_Mode POSIX permission bits (low 12 bits) to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Record a performed action in the undo history, keeping only members
   --  whose publication identity still matches the live entry. Created
   --  directories also require a matching recursive revision, and every
   --  payload needed by Undo and Redo must be complete and valid. Replacement
   --  actions are recorded only when every created and preserved entry is
   --  verifiable, since their reverse steps are inseparable. Identities,
   --  revisions and trash origins not supplied are captured here, before the
   --  model records the entry; payloads the record retires are then deleted
   --  and the history journal saved (Settle_History).
   --
   --  @param Model Model whose history is updated.
   --  @param Kind Kind of action that can be undone.
   --  @param From Current locations to undo from.
   --  @param To Restore targets or old values parallel to From.
   --  @param Forward Redo sources or new values parallel to From.
   --  @param Create_Kind Creation operation used by Redo.
   --  @param Redoable Whether a successful Undo may enter Redo history.
   --  @param Restore_Trash Preserved replacement originals to restore.
   --  @param Provenance What identifies the entries From and Restore_Trash name.
   --  @return True when a usable history entry was added.
   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>)) return Boolean;

   --  Carry out the filesystem work model history mutations queued: delete
   --  the recovery payloads of retired entries, release those of an ended
   --  history to the system trash, and save the history journal when the
   --  history changed. Call it right after each model history mutation.
   --
   --  @param Model Model whose queued history work to perform.
   procedure Settle_History (Model : in out Files.Model.Window_Model);

   --  From now on count, from zero, each attempt Try_Record_Undo makes to
   --  record an entry (Count True); or stop counting (False).
   --
   --  @param Count Whether to count.
   procedure Count_Undo_Records (Count : Boolean);

   --  @return The attempts counted since Count_Undo_Records (True).
   function Undo_Records return Natural;

   --  Make the clock a batch's Undo throttle reads a fake one (Fake True),
   --  or the real one again (False). The fake clock stands still, so no
   --  second ever passes between a batch's records, except that its
   --  Advance_At'th reading (counting from one; zero for never) moves it one
   --  second on, where it stays. The throttle reads it once for each item a
   --  batch completes, and once more when the batch ends with items not yet
   --  recorded.
   --
   --  @param Fake Whether to use the fake clock.
   --  @param Advance_At The reading that moves the clock one second on.
   procedure Fake_Checkpoint_Clock (Fake : Boolean; Advance_At : Natural := 0);

   --  @return How often the fake clock was read since Fake_Checkpoint_Clock.
   function Checkpoint_Clock_Readings return Natural;

   --  Finish Model's armed paste as one whose failed move kept a copy at
   --  Dest beside its still present Source, as the paste driver does.
   --
   --  @param Model Window whose paste finishes.
   --  @param Settings Current settings.
   --  @param Error_Key The move's own failure, or "" (cancelled).
   --  @param Dest The kept copy.
   --  @param Source The source that stayed.
   --  @param Identity The copy's identity when it was made.
   --  @param Tree_Revision The copy's tree revision when it was made.
   --  @return The paste's result.
   function Finalize_Paste_With_Kept_Copy
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Dest, Source, Identity, Tree_Revision : String)
      return Operation_Result;

end Files.Operations.Testing;
