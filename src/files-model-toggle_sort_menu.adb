separate (Files.Model)
   procedure Toggle_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := not Model.Sort_Menu_Open;
   end Toggle_Sort_Menu;
