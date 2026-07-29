separate (Files.Model)
   function Settings_Is_Capturing (Model : Window_Model) return Boolean is
   begin
      return Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View);
   end Settings_Is_Capturing;
