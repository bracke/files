separate (Files.Operations)
   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Files.Model.Home_Path (Model));
   end Navigate_Home;
