separate (Files.Model)
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active and then not Model.Rename_Fields.Is_Empty then
         declare
            Field : Rename_Field := Model.Rename_Fields.First_Element;
         begin
            Field.Value := To_Unbounded_String (Text);
            Field.Cursor := Text'Length;
            Model.Rename_Fields.Replace_Element (Model.Rename_Fields.First_Index, Field);
            Sync_Temporary_From_Field (Model, Field);
         end;
      end if;
   end Set_Rename_Text;
