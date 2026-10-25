separate (Files.Model)
procedure Retire_Payloads
  (Pending : in out Files.Types.String_Vectors.Vector;
   Entries : Undo_Entry_Vectors.Vector) is
begin
   for Action of Entries loop
      for Payload of Action.Restore_Trash loop
         Pending.Append (Payload);
      end loop;
   end loop;
end Retire_Payloads;
