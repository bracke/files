separate (Files.Model)
   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return False;
      end if;

      return Model.Root_Entries.Element (Index).Removable;
   end Root_Is_Removable;
