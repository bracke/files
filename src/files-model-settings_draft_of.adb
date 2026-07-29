separate (Files.Model)
   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
   begin
      return Model.Settings_Draft_Value;
   end Settings_Draft_Of;
