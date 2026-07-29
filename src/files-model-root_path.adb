separate (Files.Model)
   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Entries.Is_Empty or else Index > Model.Root_Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Entries.Element (Index).Path);
   end Root_Path;
