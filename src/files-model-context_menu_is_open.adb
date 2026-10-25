separate (Files.Model)
function Context_Menu_Is_Open
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Context_Menu.Open;
end Context_Menu_Is_Open;
