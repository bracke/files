separate (Files.Model)
procedure Release_History
  (Model : in out Window_Model)
is
   procedure Release (Entries : Undo_Entry_Vectors.Vector) is
   begin
      for Action of Entries loop
         for Payload of Action.Restore_Trash loop
            if Files.File_System.Is_Recovery_Payload (To_String (Payload)) then
               declare
                  Result : constant Files.File_System.Mutation_Result :=
                    Files.File_System.Release_Recovery_Payload (To_String (Payload));
                  pragma Unreferenced (Result);
               begin
                  null;
               end;
            end if;
         end loop;
      end loop;
   end Release;
begin
   Release (Model.Undo_Stack);
   Release (Model.Redo_Stack);
   Model.Undo_Stack.Clear;
   Model.Redo_Stack.Clear;
   Model.Revision_Value := Model.Revision_Value + 1;
end Release_History;
