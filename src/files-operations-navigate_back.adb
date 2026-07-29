separate (Files.Operations)
   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Navigate_History (Model, Settings, History_Back);
   end Navigate_Back;
