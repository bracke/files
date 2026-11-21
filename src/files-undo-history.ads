with Ada.Containers.Vectors;

with Files.Types;

--  The undo history's values: what one entry records to reverse (undo) and
--  re-apply (redo) an action, the two stacks, and what a history journal
--  keeps besides them. The window model holds a history
--  (Files.Model.History works on it, and Files.Model names these types as
--  its own); the journal (Files.Undo.Journal) and the recording of new
--  entries (Files.Undo.Recording) work on these values without a window.
package Files.Undo.History is

   --  Which of the two history stacks, and so which way an entry is applied:
   --  undone (reversed) from the undo stack, redone (re-applied, "forward")
   --  from the redo stack.
   type History_Side is (Undo_Side, Redo_Side);

   --  Multi-level undo/redo history. Each entry stores enough to BOTH reverse
   --  (undo) and re-apply (redo) one action: its items, each a path with what
   --  the action recorded for it; Create_Kind names the kind of creation to
   --  re-run for Undo_Delete_Created entries.
   type Undo_Action_Kind is
     (Undo_None,
      Undo_Rename,
      Undo_Move,
      Undo_Restore_Trash,
      Undo_Delete_Created,
      Undo_Set_Permissions,
      Undo_Set_Ownership);

   --  How an Undo_Delete_Created entry re-creates its paths on redo.
   type Undo_Create_Kind is
     (Create_None,
      Create_Copy,
      Create_Symbolic_Link,
      Create_Hard_Link);

   --  One path an action changed, and what the action recorded for it.
   --
   --  Undo runs the reverse direction, redo the forward direction:
   --    * Rename/Move: reverse moves From back to To, redo re-does the original
   --      To -> From transition. Forward is empty.
   --    * Restore_Trash: reverse restores the trashed From to To; it is
   --      undo-only (Redoable is False), so redo never re-runs it.
   --    * Delete_Created: reverse deletes From; redo re-creates it from the
   --      source path in Forward using Create_Kind. To is empty.
   --    * Set_Permissions: To holds the old value (reverse) and Forward the new
   --      value (redo).
   --    * Set_Ownership likewise, with each value encoded as
   --      "uid gid<NUL>user-name<NUL>group-name".  The names let a helper
   --      process reconstruct platform identities whose numeric token is only
   --      meaningful inside the process that obtained it.
   --  A value an action does not use is empty.
   type Undo_Item is record
      From          : Files.Types.UString;
      To            : Files.Types.UString;
      Forward       : Files.Types.UString;
      --  The entry at From as the action left it: for creations, moves, trash
      --  and metadata changes the current entry at either end, including a
      --  new identity after a copy-based move. An empty token never
      --  authorizes deletion, a history move, a trash restoration or a
      --  metadata change.
      Identity      : Files.Types.UString;
      --  A created directory's recursive revision at publication (empty for
      --  files and links): Undo refuses a directory whose complete tree no
      --  longer matches it.
      Tree_Revision : Files.Types.UString;
   end record;

   package Undo_Item_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Undo_Item);

   --  An original a paste-replace overwrote, preserved in the trash: on undo,
   --  once the main reverse has vacated its path, it is put back from there.
   type Replaced_Original is record
      --  Where it is preserved, and its identity there.
      Trash    : Files.Types.UString;
      Identity : Files.Types.UString;
      --  Where Undo puts it back.
      Target   : Files.Types.UString;
   end record;

   package Replaced_Original_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Replaced_Original);

   --  A copy a failed move left beside its still present source: reverse
   --  deletes it, verified by its identity and tree revision, before it moves
   --  anything back or restores an original a replace preserved, so one paste
   --  is one Undo.
   type Kept_Copy is record
      Path          : Files.Types.UString;
      Identity      : Files.Types.UString;
      Tree_Revision : Files.Types.UString;
   end record;

   package Kept_Copy_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Kept_Copy);

   --  How an action's record knows an item or a replaced original beyond
   --  what it carries (Files.Undo.Recording.Try_Record_Undo). Captured: its
   --  identity -- and a creation's tree revision, an original's target -- is
   --  read when the record is made. Published: they are as the action
   --  published them, even when empty, and an empty one never verifies.
   --  Verified: published and checked against the live entry then, so it is
   --  trusted without a fresh check and may survive a later pathname
   --  replacement.
   type Item_Provenance is (Captured, Published, Verified);

   --  An item as an action hands it to the record, with its provenance.
   type Recorded_Item is record
      Item       : Undo_Item;
      Provenance : Item_Provenance := Captured;
   end record;

   package Recorded_Item_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Recorded_Item);

   --  A replaced original as an action hands it to the record.
   type Recorded_Original is record
      Original   : Replaced_Original;
      Provenance : Item_Provenance := Captured;
   end record;

   package Recorded_Original_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Recorded_Original);

   --  A single reversible/re-applicable action.
   type Undo_Entry is record
      Kind        : Undo_Action_Kind := Undo_None;
      Items       : Undo_Item_Vectors.Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      --  Originals a paste-replace overwrote. Empty for every other action.
      --  Undo-only (a paste that replaced anything is not redoable).
      Replaced : Replaced_Original_Vectors.Vector;
      --  Successful reverse steps retained after a partial Undo (a From path
      --  or a kept copy's). A retry must never delete or move an original
      --  that an earlier pass restored.
      Reverse_Completed : Files.Types.String_Vectors.Vector;
      --  The Trash paths of originals already put back.
      Restores_Completed : Files.Types.String_Vectors.Vector;
      --  Successful creation/move steps retained after a partial Redo, so a
      --  retry skips committed items instead of treating them as collisions.
      Forward_Completed : Files.Types.String_Vectors.Vector;
      --  Verified hard-link families retained across partial copy Redo retries.
      Copy_Records : Files.Types.String_Vectors.Vector;
      --  Set only on a non-redoable Undo_Move. Their completion markers join
      --  Reverse_Completed.
      Kept : Kept_Copy_Vectors.Vector;
      --  Who the entry is across processes: a background helper's history
      --  journal names entries by it, so the window can tell an entry the
      --  helper left out of its journal from one it retired. Given by
      --  Commit_Undo_Record; 0 until then.
      Sequence : Natural := 0;
   end record;

   --  @param Action Entry to read.
   --  @return Each item's From path, in order.
   function From_Paths (Action : Undo_Entry) return Files.Types.String_Vectors.Vector;

   --  @param Action Entry to read.
   --  @return Where each replaced original is preserved, in order.
   function Replaced_Trash (Action : Undo_Entry) return Files.Types.String_Vectors.Vector;

   --  Stack of undo/redo entries; the last element is the top of the stack.
   package Undo_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Undo_Entry);

   --  Undo_Entry.Sequence values.
   package Sequence_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Positive);

   --  What a history journal holds besides its stacks.
   type History_Journal_State is record
      --  The Sequence the next recorded entry gets.
      Next_Sequence : Positive := 1;
      --  Sequences of entries still in the history but left out of the
      --  journal (too old, or too large, to fit it).
      Unjournaled   : Sequence_Vectors.Vector;
      --  Whether a new record retired the redo stack since the history was
      --  loaded: redo entries the loader never saw are retired with it.
      Redo_Retired  : Boolean := False;
      --  Sequences of entries still in the history but neither in the journal
      --  nor listed in Unjournaled: the journal's cap on that list left them
      --  out. A window merging the journal retires them, releasing what they
      --  preserved, rather than taking them for entries a helper retired.
      Dropped       : Sequence_Vectors.Vector;
   end record;

   --  The undo history: the two stacks, the work owed to the operations
   --  layer (Files.Model.History.Take_Retired) -- payloads of retired entries to delete,
   --  payloads of a released history to send to the trash -- whether the
   --  history changed since it was last saved, and what its journal holds
   --  besides the stacks. Every default is the empty history.
   type Undo_History_State is record
      Undo_Stack       : Undo_Entry_Vectors.Vector;
      Redo_Stack       : Undo_Entry_Vectors.Vector;
      Retired_Discards : Files.Types.String_Vectors.Vector;
      Retired_Releases : Files.Types.String_Vectors.Vector;
      Journal_Dirty    : Boolean := False;
      Journal          : History_Journal_State;
   end record;

end Files.Undo.History;
