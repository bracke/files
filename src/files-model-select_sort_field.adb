separate (Files.Model)
procedure Select_Sort_Field
  (Model : in out Window_Model;
   Field : Files.Types.Sort_Field)
is
   use type Files.Types.Sort_Field;
begin
   Touch (Model);
   if Model.Sort_Field_Value = Field then
      Model.Sort_Ascending := not Model.Sort_Ascending;
   else
      Model.Sort_Field_Value := Field;
      Model.Sort_Ascending := True;
   end if;

   Model.Sort_Menu.Open := False;
   Model.Main_View_Scroll := 0;
   Resort_Items (Model);
end Select_Sort_Field;
