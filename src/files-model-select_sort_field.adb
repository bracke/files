separate (Files.Model)
   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Sort_Field) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Sort_Field_Value = Field then
         Model.Sort_Ascending := not Model.Sort_Ascending;
      else
         Model.Sort_Field_Value := Field;
         Model.Sort_Ascending := True;
      end if;

      Model.Sort_Menu_Open := False;
      Model.Main_View_Scroll := 0;
      Resort_Items (Model);
   end Select_Sort_Field;
