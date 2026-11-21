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

end Files.Operations.Undo_Recording;
