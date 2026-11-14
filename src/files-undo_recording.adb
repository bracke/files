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

   function Try_Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Undo_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Replaced_Original_Vectors.Vector :=
        Files.Model.Replaced_Original_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>)) return Boolean is separate;

   procedure Record_Undo
     (Model       : in out Files.Model.Window_Model;
      Kind        : Files.Model.Undo_Action_Kind;
      Items       : Files.Model.Undo_Item_Vectors.Vector;
      Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
      Redoable    : Boolean := True;
      Replaced    : Files.Model.Replaced_Original_Vectors.Vector :=
        Files.Model.Replaced_Original_Vectors.Empty_Vector;
      Provenance  : Undo_Provenance := (others => <>))
   is
      Recorded : constant Boolean :=
        Try_Record_Undo (Model, Kind, Items, Create_Kind, Redoable, Replaced, Provenance);
      pragma Unreferenced (Recorded);
   begin
      null;
   end Record_Undo;

   procedure Settle_History (Model : in out Files.Model.Window_Model) is separate;

end Files.Undo_Recording;
