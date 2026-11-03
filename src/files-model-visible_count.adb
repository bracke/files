separate (Files.Model)
function Visible_Count
  (Model : Window_Model)
   return Natural
is
begin
   return Visible_Item_Count (Model) + (if Temporary_Is_Visible (Model) then 1 else 0);
end Visible_Count;
