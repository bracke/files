--  Copying, moving and publishing entries: drop and paste plans, the
--  import that preserves what it replaces and puts it back on failure,
--  tree copies, staged publication, and the cancel-versus-failure rule.
--  Clients with this, not the whole of Files.File_System.
package Files.File_System.Transfer is

   --  Recursively copy a file or directory tree to a new destination path.
   --
   --  The destination must not already exist. Directories are copied with their
   --  full contents. Used by the duplicate command.
   --
   --  @param Source_Path Existing file or directory to copy.
   --  @param Destination_Path New path to create.
   --  @param Batch Shared hard-link journal for consecutive copies.
   --  @return Mutation result with a localized error key on failure.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Copy while returning snapshots captured before atomic publication.
   --  @param Source_Path Existing file or directory to copy.
   --  @param Destination_Path New path to create.
   --  @param Identity Published entry identity.
   --  @param Tree_Revision_Value Directory or regular-file revision, empty for links.
   --  @param Batch Shared hard-link journal for consecutive copies.
   --  @return Mutation result with a localized error key on failure.
   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Put a staged file or folder at Target, never over an entry already
   --  there: its identity and tree revision taken first, the whole of it
   --  flushed to the device (a power cut leaves no recorded but empty or cut
   --  short output), named as intended (Files.Jobs.Context.Intend_Created),
   --  renamed into place, given the access its new folder hands down (as a
   --  published copy is, its revision read again where that changed it and
   --  named again with it), recorded as created, and its new name flushed --
   --  the publication Copy_Tree's copies share (Copying.Publish_From_Stage). A failure of that last
   --  flush is traced, not returned: the entry is published and recorded,
   --  as a Durable_Writes publication that is Published_Not_Durable. The one
   --  way Compress and Extract publish what they made.
   --
   --  @param Staged The finished file or folder inside a stage.
   --  @param Target Where it is published.
   --  @param Identity Set to its identity token, for its Undo.
   --  @param Revision Set to its tree revision, for its Undo.
   --  @return False when it was not published; Staged is then left for the
   --    caller to discard with its stage.
   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out UString;
      Revision : out UString)
      return Boolean;

   --  Build deterministic copy/move plans for paths dropped into a directory.
   --
   --  @param Source_Paths Paths received from a drag-and-drop operation.
   --  @param Destination_Directory Directory receiving the dropped entries.
   --  @param Mode Copy or move mode for all valid plans.
   --  @return Planned destination paths and validation diagnostics.
   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result;

   --  The one rule for telling a cancel from a failure of its own: whether a
   --  failure key says no more than that the work stopped -- no key, a
   --  cancel, an interruption, or, read at a Copy_Step, the generic
   --  "error.drop.failed". A cancelled job's failure with such a key is
   --  reported as the cancel; any other key (a full disk, a collision) has
   --  a cause of its own and is reported as such.
   --  @param Error_Key The failure's message key.
   --  @param Reading Where the key is read.
   --  @return True when the key names no cause beyond the stop.
   function Says_Only_Stopped (Error_Key : String; Reading : Failure_Reading) return Boolean;

   --  The job's own cancellation (Files.Jobs.Context.Cancelled): what a copy
   --  or a check stops for unless it is handed another check, or null for
   --  none -- recovery, which must finish once the job is cancelled.
   --  @return Files.Jobs.Context.Cancelled.
   function Job_Cancelled return Cancellation_Check;

   --  Import one paste action, preserving the destination it replaces first
   --  and putting that original back when the import fails. The one routine
   --  behind both the in-process paste and the transfer helper: a replace
   --  target that vanished after planning has nothing to preserve and the
   --  import proceeds; a destination that is the source itself is never
   --  preserved, so a same-path move is a no-op success (and a same-path
   --  copy fails as Execute_Drop_Import fails it).
   --  @param Source Entry to copy or move.
   --  @param Destination New pathname.
   --  @param Mode Copy or move.
   --  @param Replace Whether an existing Destination is to be replaced.
   --  @param Replaced Where the replaced original is held, or empty: empty
   --    when nothing was preserved or the original was put back.
   --  @param Replaced_Identity Identity of Replaced, or empty.
   --  @param Created_Identity Identity of the published destination.
   --  @param Created_Tree_Revision Tree revision of the published destination.
   --  @param Preserved Called once the original is held at Backup (with its
   --    identity), before the import starts -- also when preserving failed
   --    yet left the original there; an exception from it fails the action
   --    and the original is put back.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal.
   --  @return Success when Destination holds the imported entry; otherwise
   --    the preserving, import, or restoring failure. A cross-device move
   --    that failed yet had to keep its copy at Destination (see
   --    Execute_Drop_Import) also fails, with Created_Identity set to that
   --    copy and the original left held at Replaced: Destination is taken,
   --    so the original is not put back, and the caller records both.
   function Import_Replacing
     (Source, Destination   : String;
      Mode                  : Drop_Import_Mode;
      Replace               : Boolean;
      Replaced              : out Files.Types.UString;
      Replaced_Identity     : out Files.Types.UString;
      Created_Identity      : out Files.Types.UString;
      Created_Tree_Revision : out Files.Types.UString;
      Preserved             : access procedure (Backup, Backup_Identity : String) := null;
      Cancel                : Cancellation_Check := Job_Cancelled;
      Batch                 : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Put an original that a failed replace preserved back at Destination:
   --  the one rollback behind Import_Replacing and the transfer helper. With
   --  nothing held (Replaced empty) it does nothing.
   --  @param Replaced Where the original is held; emptied once it is back.
   --  @param Replaced_Identity Identity of Replaced; emptied with it.
   --  @param Destination Where the original came from.
   --  @param Result The action's result, replaced by the restore's failure
   --    when the original cannot be put back.
   procedure Put_Back_Replaced
     (Replaced, Replaced_Identity : in out Files.Types.UString;
      Destination                 : String;
      Result                      : in out Mutation_Result);
end Files.File_System.Transfer;
