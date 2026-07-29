separate (Files.Model)
package body Context_Menu is

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
      --  No keyboard highlight until the user arrows; a mouse-opened menu shows
      --  none pre-selected.
      Model.Context_Menu_Highlight_Value := 0;
   end Open_Context_Menu;

   procedure Close_Context_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Context_Menu_Open_Value := False;
      Model.Context_Menu_Target_Value := Context_Menu_None;
      Model.Context_Menu_Item_Index_Value := 0;
      Model.Context_Menu_Highlight_Value := 0;
   end Close_Context_Menu;

   procedure Set_Context_Menu_Highlight
     (Model : in out Window_Model;
      Row   : Natural) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Context_Menu_Highlight_Value := Row;
   end Set_Context_Menu_Highlight;

   function Context_Menu_Highlight
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_Highlight_Value;
   end Context_Menu_Highlight;

   function Context_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Context_Menu_Open_Value;
   end Context_Menu_Is_Open;

   function Context_Menu_X
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_X_Value;
   end Context_Menu_X;

   function Context_Menu_Y
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_Y_Value;
   end Context_Menu_Y;

   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target is
   begin
      return Model.Context_Menu_Target_Value;
   end Context_Menu_Target_Of;

   function Context_Menu_Item_Index
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Context_Menu_Item_Index_Value;
   end Context_Menu_Item_Index;

end Context_Menu;
