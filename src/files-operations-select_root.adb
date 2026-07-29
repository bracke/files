separate (Files.Operations)
   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Root_Path, Close_Selector => True);
   end Select_Root;
