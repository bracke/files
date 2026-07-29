separate (Files.Model)
   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Last  : constant Natural := Length (Field.Value);
         begin
            if Field.Cursor /= Last then
               Field.Cursor := Last;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Set_All_Carets_End;
