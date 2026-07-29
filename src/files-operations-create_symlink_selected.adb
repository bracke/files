separate (Files.Operations)
   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => False);
   end Create_Symlink_Selected;
