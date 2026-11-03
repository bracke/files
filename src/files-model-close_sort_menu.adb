separate (Files.Model)
procedure Close_Sort_Menu
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Sort_Menu_Open := False;
end Close_Sort_Menu;
