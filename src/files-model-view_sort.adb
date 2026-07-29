with Files.Model.Support;

separate (Files.Model)
package body View_Sort is

   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is
   begin
      return Model.View_Value;
   end View_Mode_Of;

   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.View_Value := Mode;
      Model.Main_View_Scroll := 0;
   end Set_View_Mode;

   function Sort_Field_Of
     (Model : Window_Model)
      return Sort_Field is
   begin
      return Model.Sort_Field_Value;
   end Sort_Field_Of;

   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Ascending;
   end Sort_Is_Ascending;

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

   procedure Toggle_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := not Model.Sort_Menu_Open;
      --  Open the menu with the keyboard highlight on the current sort field
      --  (rows 1 .. 5 mirror Sort_Field'Val 0 .. 4).
      if Model.Sort_Menu_Open then
         Model.Sort_Menu_Highlight_Value := Sort_Field'Pos (Model.Sort_Field_Value) + 1;
      end if;
   end Toggle_Sort_Menu;

   procedure Move_Sort_Menu_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is
      Current : constant Natural :=
        (if Model.Sort_Menu_Highlight_Value = 0 then 1 else Model.Sort_Menu_Highlight_Value);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Highlight_Value :=
        Integer'Max (1, Integer'Min (5, Current + Delta_Value));
   end Move_Sort_Menu_Highlight;

   function Sort_Menu_Highlight
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Sort_Menu_Highlight_Value;
   end Sort_Menu_Highlight;

   function Sort_Menu_Highlight_Field
     (Model : Window_Model)
      return Sort_Field is
   begin
      if Model.Sort_Menu_Highlight_Value in 1 .. 5 then
         return Sort_Field'Val (Model.Sort_Menu_Highlight_Value - 1);
      else
         return Sort_Name;
      end if;
   end Sort_Menu_Highlight_Field;

   procedure Close_Sort_Menu
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Sort_Menu_Open := False;
   end Close_Sort_Menu;

   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Sort_Menu_Open;
   end Sort_Menu_Is_Open;

end View_Sort;
