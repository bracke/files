separate (Files.Model)
function Root_Entry_At
  (Model : Window_Model;
   Index : Positive)
   return Files.File_System.Root_Entry is
begin
   if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
      return (others => <>);
   end if;

   return Model.Root_Selector.Entries.Element (Index);
end Root_Entry_At;
