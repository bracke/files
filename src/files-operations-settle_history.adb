separate (Files.Operations)
procedure Settle_History (Model : in out Files.Model.Window_Model) is
   Discarded, Released : Files.Types.String_Vectors.Vector;
   Journal_Dirty : Boolean;
begin
   Files.Model.Take_Retired_History (Model, Discarded, Released, Journal_Dirty);
   --  The model queues a payload only once no stack holds its entry, so
   --  nothing can still restore it from here.
   for Payload of Discarded loop
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
   for Payload of Released loop
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
   if Journal_Dirty then
      Files.History_Journal.Save (Model);
   end if;
end Settle_History;
