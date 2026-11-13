separate (Files.Model)
function Root_Is_Removable
  (Model : Window_Model;
   Index : Positive)
   return Boolean is
begin
   if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
      return False;
   end if;

   return Model.Root_Selector.Entries.Element (Index).Removable;
end Root_Is_Removable;
