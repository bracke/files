separate (Files.Model)
procedure Discard_Retained (Action : Undo_Entry) is
begin
   for Payload of Action.Restore_Trash loop
      if Files.File_System.Is_Recovery_Payload (To_String (Payload)) then
         declare
            Result : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Trashed_Item (To_String (Payload));
            pragma Unreferenced (Result);
         begin
            null;
         end;
      end if;
   end loop;
end Discard_Retained;
