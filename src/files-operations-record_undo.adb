separate (Files.Operations)
procedure Record_Undo
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
   Provenance  : Undo_Provenance := (others => <>))
is
   Recorded : constant Boolean := Try_Record_Undo
     (Model, Kind, From, To, Forward, Create_Kind, Redoable, Restore_Trash, Provenance);
   pragma Unreferenced (Recorded);
begin
   null;
end Record_Undo;
