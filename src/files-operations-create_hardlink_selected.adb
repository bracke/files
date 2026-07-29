separate (Files.Operations)
   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => True);
   end Create_Hardlink_Selected;
