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
   Original_Identities : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Retain_Verified_Main : Natural := 0;
   Retain_Verified_Restores : Natural := 0)
is
   Recorded : constant Boolean := Try_Record_Undo
     (Model, Kind, From, To, Forward, Create_Kind, Redoable, Restore_Trash,
      Original_Identities, Original_Tree_Revisions,
      Original_Restore_Identities, Original_Restore_Targets,
      Retain_Verified_Main, Retain_Verified_Restores);
   pragma Unreferenced (Recorded);
begin
   null;
end Record_Undo;
