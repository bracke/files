with Files.Model.Support;

package body Files.Model.View_Sort is
   use Files.Model.Support;

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
   end Toggle_Sort_Menu;

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

end Files.Model.View_Sort;
