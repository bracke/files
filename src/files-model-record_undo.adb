separate (Files.Model)
   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Kind = Undo_None or else From.Is_Empty then
         return;
      end if;

      Model.Undo_Stack.Append
        (Undo_Entry'
           (Kind          => Kind,
            From          => From,
            To            => To,
            Forward       => Forward,
            Create_Kind   => Create_Kind,
            Redoable      => Redoable,
            Restore_Trash => Restore_Trash));
      Model.Redo_Stack.Clear;
   end Record_Undo;
