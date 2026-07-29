separate (Files.Model)
   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return Files.File_System.Root_Filesystem;
      end if;

      return Model.Root_Entries.Element (Index).Kind;
   end Root_Kind;
