separate (Files.Model)
   function Settings_Active_Section (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Active_Section (Model.Settings_Panel_View);
   end Settings_Active_Section;
