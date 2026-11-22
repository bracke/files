with Files.Timing;
with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.File_Identities;
with Files.File_System;
with Files.File_System.Trash;
with Files.Undo.Journal;
with Files.Model.History;
with Files.Types;
with Files.Undo.Payloads;

package body Files.Operations.Undo_Recording is
   use Ada.Strings.Unbounded;
   use type Files.Undo.History.Undo_Action_Kind;
   use type Files.Undo.History.Undo_Create_Kind;

   function With_Provenance
     (Items      : Files.Undo.History.Undo_Item_Vectors.Vector;
      Provenance : Files.Undo.History.Item_Provenance) return Files.Undo.History.Recorded_Item_Vectors.Vector is
   begin
      return Result : Files.Undo.History.Recorded_Item_Vectors.Vector do
         for Item of Items loop
            Result.Append (Files.Undo.History.Recorded_Item'(Item => Item, Provenance => Provenance));
         end loop;
      end return;
   end With_Provenance;

   function Captured
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Undo.History.Captured));

   function Captured
     (Originals : Files.Undo.History.Replaced_Original_Vectors.Vector)
      return Files.Undo.History.Recorded_Original_Vectors.Vector is
   begin
      return Result : Files.Undo.History.Recorded_Original_Vectors.Vector do
         for Original of Originals loop
            Result.Append
              (Files.Undo.History.Recorded_Original'(Original => Original, Provenance => Files.Undo.History.Captured));
         end loop;
      end return;
   end Captured;

   function Published
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Undo.History.Published));

   function Verified
     (Items : Files.Undo.History.Undo_Item_Vectors.Vector) return Files.Undo.History.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Undo.History.Verified));

   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
      return Boolean is separate;

   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Undo.History.Undo_Action_Kind;
      Items       : Files.Undo.History.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Undo.History.Undo_Create_Kind := Files.Undo.History.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Undo.History.Recorded_Original_Vectors.Vector :=
        Files.Undo.History.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Undo.History.Kept_Copy_Vectors.Vector := Files.Undo.History.Kept_Copy_Vectors.Empty_Vector)
   is
      Recorded : constant Boolean :=
        Try_Record_Undo (Model, Kind, Items, Create_Kind, Redoable, Replaced, Kept);
      pragma Unreferenced (Recorded);
   begin
      null;
   end Record_Undo;

   procedure Settle_History (Model : in out Files.Model.Window_Model) is separate;

   --  How long Checkpoint_Undo leaves between records.
   Checkpoint_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);

   --  The throttle's clock: the test suite's when it set one.
   function Checkpoint_Now return Ada.Real_Time.Time is
      Hook : constant Clock_Hook := Checkpoint_Clock;
   begin
      return (if Hook = null then Ada.Real_Time.Clock else Hook.all);
   end Checkpoint_Now;

   --  Replace the batch's entry with one covering every item appended.
   --  Now is the throttle's clock reading the record is made at.
   procedure Record_Progress
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo;
      Now      : Ada.Real_Time.Time)
   is
      Previous : Files.Undo.History.Undo_Entry;
      Found    : Boolean;
   begin
      if Progress.Recorded then
         Files.Model.History.Take_Undo (Model, Previous, Found);
         --  Taken: should the record below raise, a later one must not
         --  take the entry under it, which is not the batch's.
         Progress.Recorded := False;
      end if;
      --  Counted before the record, which may raise: a failed attempt is
      --  not retried until the next interval either.
      Progress.Attempted := True;
      Progress.Attempted_Count := Natural (Progress.Items.Length);
      Progress.Last_Checkpoint := Now;
      Progress.Recorded := Files.Operations.Undo_Recording.Try_Record_Undo
        (Model, Progress.Kind, Progress.Items,
         Create_Kind => Progress.Create_Kind,
         Redoable    => Progress.Redoable);
      --  Every item a record admitted was verified then: a later checkpoint
      --  trusts it, though its path has since been reused.
      if Progress.Recorded
        and then Natural (Files.Model.History.Undo_From_Paths (Model).Length) = Natural (Progress.Items.Length)
      then
         for Item of Progress.Items loop
            Item.Provenance := Files.Undo.History.Verified;
         end loop;
      end if;
      if Progress.Durable then
         Files.Undo.Journal.Save (Files.Model.History.State (Model), Mode => Files.Undo.Journal.Must_Commit);
      end if;
   end Record_Progress;

   procedure Checkpoint_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo)
   is
      --  Read once a call, whether or not it records, so a test clock
      --  counts one reading per item.
      Now : constant Ada.Real_Time.Time := Checkpoint_Now;
   begin
      if not Progress.Attempted
        or else Files.Timing.Elapsed (Now, Progress.Last_Checkpoint, Checkpoint_Interval)
      then
         Record_Progress (Model, Progress, Now);
      end if;
   end Checkpoint_Undo;

   function Finish_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) return Undo_Outcome is
   begin
      if Natural (Progress.Items.Length) /= Progress.Attempted_Count then
         Record_Progress (Model, Progress, Checkpoint_Now);
      end if;
      return (if Progress.Items.Is_Empty or else Progress.Recorded then Undo_Covered else Undo_Unavailable);
   end Finish_Undo;

   procedure Note_Undo_Outcome
     (Model   : in out Files.Model.Window_Model;
      Outcome : Undo_Outcome;
      Result  : Operation_Result) is
   begin
      if Outcome = Undo_Unavailable and then Result.Status = Operation_Success then
         Files.Model.Set_Error (Model, Undo_Unavailable_Notice);
      end if;
   end Note_Undo_Outcome;

   procedure Finish_Failed_Undo
     (Model    : in out Files.Model.Window_Model;
      Progress : in out Progressive_Undo) is
   begin
      declare
         --  The batch's own failure is reported; a missing Undo is no news.
         Outcome : constant Undo_Outcome := Finish_Undo (Model, Progress);
         pragma Unreferenced (Outcome);
      begin
         null;
      end;
   exception
      when Unrecorded : others =>
         Files.Diagnostics.Note (Unrecorded, "Files.Operations.Support");
   end Finish_Failed_Undo;

end Files.Operations.Undo_Recording;
