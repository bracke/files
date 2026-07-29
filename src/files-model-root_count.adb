separate (Files.Model)
   function Root_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Root_Entries.Length);
   end Root_Count;
