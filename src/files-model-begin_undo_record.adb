separate (Files.Model)
procedure Begin_Undo_Record
  (Model : in out Window_Model;
   Kind  : Undo_Action_Kind;
   From  : Files.Types.String_Vectors.Vector;
   To    : Files.Types.String_Vectors.Vector) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   if Kind = Undo_None or else From.Is_Empty then
      return;
   end if;
   --  A rename or move is recorded once it is done, whether or not it can
   --  be undone: To holds the old paths, From the new ones.
   if Kind in Undo_Rename | Undo_Move then
      for Index in From.First_Index .. From.Last_Index loop
         if Index <= To.Last_Index then
            Note_Path_Move (Model, To_String (To (Index)), To_String (From (Index)));
         end if;
      end loop;
   end if;
end Begin_Undo_Record;
