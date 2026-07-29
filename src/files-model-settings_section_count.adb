separate (Files.Model)
   function Settings_Section_Count (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Section_Count (Model.Settings_Panel_View);
   end Settings_Section_Count;
