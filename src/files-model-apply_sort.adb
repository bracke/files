separate (Files.Model)
   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Sort_Field;
      Ascending : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Field_Value := Field;
      Model.Sort_Ascending   := Ascending;
      Resort_Items (Model);
   end Apply_Sort;
