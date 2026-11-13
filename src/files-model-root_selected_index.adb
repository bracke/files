separate (Files.Model)
function Root_Selected_Index
  (Model : Window_Model)
   return Natural is
begin
   if not Model.Root_Selector.Open
     or else Model.Root_Selector.Selected = 0
     or else Model.Root_Selector.Selected > Root_Count (Model)
   then
      return 0;
   end if;

   return Model.Root_Selector.Selected;
end Root_Selected_Index;
