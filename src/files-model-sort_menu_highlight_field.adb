separate (Files.Model)
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
