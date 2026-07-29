separate (Files.Model)
   procedure Close_Context_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Context_Menu_Open_Value := False;
      Model.Context_Menu_Target_Value := Context_Menu_None;
      Model.Context_Menu_Item_Index_Value := 0;
   end Close_Context_Menu;
