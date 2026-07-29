separate (Files.Model)
   procedure Close_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := False;
   end Close_Sort_Menu;
