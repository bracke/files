separate (Files.Model)
function Root_Label
  (Model : Window_Model;
   Index : Positive)
   return String is
begin
   if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
      return "";
   end if;

   return To_String (Model.Root_Selector.Entries.Element (Index).Label);
end Root_Label;
