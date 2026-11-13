separate (Files.Model)
function Rename_Set_All_Carets_Home
  (Model : in out Window_Model)
   return Boolean
is
   Changed : Boolean := False;
begin
   Touch (Model);
   for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
      declare
         Field : Rename_Field := Model.Rename.Fields.Element (Index);
      begin
         if Field.Cursor /= 0 then
            Field.Cursor := 0;
            Model.Rename.Fields.Replace_Element (Index, Field);
            Changed := True;
         end if;
      end;
   end loop;

   return Changed;
end Rename_Set_All_Carets_Home;
