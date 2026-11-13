separate (Files.Model)
function Root_Kind
  (Model : Window_Model;
   Index : Positive)
   return Files.File_System.Root_Kind is
begin
   if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
      return Files.File_System.Root_Filesystem;
   end if;

   return Model.Root_Selector.Entries.Element (Index).Kind;
end Root_Kind;
