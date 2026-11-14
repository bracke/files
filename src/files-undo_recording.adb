with Ada.Strings.Unbounded;
with Files.Diagnostics;
with Files.File_Identities;
with Files.File_System;
with Files.File_System.Trash;
with Files.History_Journal;
with Files.Model.History;
with Files.Types;
with Files.Undo_Payloads;

package body Files.Undo_Recording is
   use Ada.Strings.Unbounded;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Model.Undo_Create_Kind;

   function With_Provenance
     (Items      : Files.Model.Undo_Item_Vectors.Vector;
      Provenance : Files.Model.Item_Provenance) return Files.Model.Recorded_Item_Vectors.Vector is
   begin
      return Result : Files.Model.Recorded_Item_Vectors.Vector do
         for Item of Items loop
            Result.Append (Files.Model.Recorded_Item'(Item => Item, Provenance => Provenance));
         end loop;
      end return;
   end With_Provenance;

   function Captured
     (Items : Files.Model.Undo_Item_Vectors.Vector) return Files.Model.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Model.Captured));

   function Captured
     (Originals : Files.Model.Replaced_Original_Vectors.Vector) return Files.Model.Recorded_Original_Vectors.Vector is
   begin
      return Result : Files.Model.Recorded_Original_Vectors.Vector do
         for Original of Originals loop
            Result.Append (Files.Model.Recorded_Original'(Original => Original, Provenance => Files.Model.Captured));
         end loop;
      end return;
   end Captured;

   function Published
     (Items : Files.Model.Undo_Item_Vectors.Vector) return Files.Model.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Model.Published));

   function Verified
     (Items : Files.Model.Undo_Item_Vectors.Vector) return Files.Model.Recorded_Item_Vectors.Vector is
     (With_Provenance (Items, Files.Model.Verified));

   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Recorded_Original_Vectors.Vector :=
        Files.Model.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Model.Kept_Copy_Vectors.Vector := Files.Model.Kept_Copy_Vectors.Empty_Vector)
      return Boolean is separate;

   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Recorded_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Recorded_Original_Vectors.Vector :=
        Files.Model.Recorded_Original_Vectors.Empty_Vector;
      Kept        : Files.Model.Kept_Copy_Vectors.Vector := Files.Model.Kept_Copy_Vectors.Empty_Vector)
   is
      Recorded : constant Boolean :=
        Try_Record_Undo (Model, Kind, Items, Create_Kind, Redoable, Replaced, Kept);
      pragma Unreferenced (Recorded);
   begin
      null;
   end Record_Undo;

   procedure Settle_History (Model : in out Files.Model.Window_Model) is separate;

end Files.Undo_Recording;
