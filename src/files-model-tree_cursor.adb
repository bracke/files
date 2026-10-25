separate (Files.Model)
function Tree_Cursor
  (Model : Window_Model)
   return String is
begin
   return To_String (Model.Tree_Cursor_Value);
end Tree_Cursor;
