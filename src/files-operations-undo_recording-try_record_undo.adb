separate (Files.Operations.Undo_Recording)
function Try_Record_Undo
  (Model       : in out Files.Model.Window_Model;
   Kind        : Files.Undo.History.Undo_Action_Kind;
   Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
   Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
   Redoable    : Boolean := True;
   Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
     Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
   Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
   return Boolean
is
   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;
   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean) return Boolean
     renames Files.File_System.Creation_Matches;
   function Valid_Natural_Image (Value : Unbounded_String) return Boolean is
     (Files.Undo.Payloads.Is_Mode_Text (To_String (Value)));
   function Valid_Ownership_Image (Value : Unbounded_String) return Boolean is
     (Files.Undo.Payloads.Is_Ownership_Text (To_String (Value)));

   use type Files.Undo.History.Item_Provenance;

   --  The items and originals as given, completed with what was not.
   Completed : Files.Undo.History.Undo_Item_Vectors.Vector;
   Restores : Files.Undo.History.Replaced_Original_Vectors.Vector;
   --  What the entry keeps: each verified item and kept copy.
   Kept_Items  : Files.Undo.History.Undo_Item_Vectors.Vector;
   Kept_Copies : Files.Undo.History.Kept_Copy_Vectors.Vector;
   --  An entry that deletes kept copies first is undo-only: redoing the move
   --  would collide with the sources the failed move left in place.
   Entry_Redoable : constant Boolean := Redoable and then Kept.Is_Empty;
   Entry_Kind : Files.Undo.History.Undo_Action_Kind := Kind;
   Invalid_Main : Boolean := False;
   Invalid_Restore : Boolean := False;
   Recorded : Boolean;

   function Tree_Revision_Or_Empty (Path : String) return String is
   begin
      return Files.File_System.Tree_Revision (Path);
   exception
      --  A creation may already be published when its snapshot is captured.
      --  Keep the operation successful, but omit unsafe Undo for this entry.
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operations.Undo_Recording");
         return "";
   end Tree_Revision_Or_Empty;

   --  An item or original verified at publication is trusted without a
   --  fresh check.
   function Main_Was_Verified (Index : Positive) return Boolean is
     (Items (Index).Provenance = Files.Undo.History.Verified);

   function Restore_Was_Verified (Index : Positive) return Boolean is
     (Replaced (Index).Provenance = Files.Undo.History.Verified);

   function Payload_Is_Complete (Item : Files.Undo.History.Undo_Item) return Boolean is separate;

   --  Complete each item the caller captured rather than verified: its
   --  identity, a creation's tree revision, a trash restore's target.
   procedure Capture_Items is separate;

   --  Complete each captured original, then mark the restores invalid when
   --  one cannot be checked or the entry would be redone.
   procedure Check_Restores is separate;

   --  Keep each item whose payload is complete and whose identity still
   --  matches, stripped to what the entry's kind uses.
   procedure Verify_Items is separate;

   --  Keep each kept copy that is still the one the failed move published.
   procedure Verify_Kept_Copies is separate;

   --  Make the kept sets agree: all or nothing for a replacement reversal,
   --  and kept copies alone undone as creations.
   procedure Settle_Sets is separate;
begin
   --  The model advances its revision and notes completed renames and moves;
   --  everything that reads the filesystem happens here, before the model
   --  commits the entry.
   for Given of Items loop
      Completed.Append (Given.Item);
   end loop;
   for Given of Replaced loop
      Restores.Append (Given.Original);
   end loop;
   Files.Model.History.Begin_Undo_Record (Model, Kind, Completed);
   if Kind = Files.Undo.History.Undo_None or else (Items.Is_Empty and then Kept.Is_Empty) then
      return False;
   end if;
   if Undo_Record_Attempted /= null then
      Undo_Record_Attempted.all;
   end if;

   Capture_Items;
   Check_Restores;
   Verify_Items;
   Verify_Kept_Copies;
   Settle_Sets;

   --  The model retires the redo stack (and, past its depth cap, the oldest
   --  undo entries) before pushing; their payloads are deleted and the
   --  journal saved only once the entries have left both stacks.
   Recorded := Files.Model.History.Commit_Undo_Record
     (Model,
      Files.Undo.History.Undo_Entry'
        (Kind        => Entry_Kind,
         Items       => Kept_Items,
         Create_Kind => Create_Kind,
         Redoable    => Entry_Redoable,
         Replaced    => Restores,
         Kept        => Kept_Copies,
         others      => <>));
   Settle_History (Model);
   return Recorded;
end Try_Record_Undo;
