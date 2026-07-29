separate (Files.Model)
   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is
   begin
      return Selected_Count (Model) >= 1 and then not Selection_Includes_Temporary (Model);
   end Rename_Is_Enabled;
