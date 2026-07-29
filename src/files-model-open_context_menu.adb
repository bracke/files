separate (Files.Model)
   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Context_Menu_Open_Value := True;
      Model.Context_Menu_X_Value := X;
      Model.Context_Menu_Y_Value := Y;
      Model.Context_Menu_Target_Value := Target;
      Model.Context_Menu_Item_Index_Value := Item_Index;
   end Open_Context_Menu;
