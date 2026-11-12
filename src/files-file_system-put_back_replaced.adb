separate (Files.File_System)
procedure Put_Back_Replaced
  (Replaced, Replaced_Identity : in out Files.Types.UString;
   Destination                 : String;
   Result                      : in out Mutation_Result)
is
begin
   if Length (Replaced) = 0 then
      return;
   end if;
   declare
      Restored : constant Mutation_Result :=
        Restore_From_Trash (To_String (Replaced), To_String (Replaced_Identity), Destination);
   begin
      if Restored.Success then
         Replaced := Null_Unbounded_String;
         Replaced_Identity := Null_Unbounded_String;
      else
         Result := Restored;
      end if;
   end;
end Put_Back_Replaced;
