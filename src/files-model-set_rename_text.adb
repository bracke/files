separate (Files.Model)
procedure Set_Rename_Text
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   if Model.Rename.Active and then not Model.Rename.Fields.Is_Empty then
      declare
         Field : Rename_Field := Model.Rename.Fields.First_Element;
      begin
         Field.Value := To_Unbounded_String (Text);
         Field.Cursor := Text'Length;
         Model.Rename.Fields.Replace_Element (Model.Rename.Fields.First_Index, Field);
         Sync_Temporary_From_Field (Model, Field);
      end;
   end if;
end Set_Rename_Text;
