separate (Files.Model)
   function Settings_Capturing_Key (Model : Window_Model) return String is
   begin
      return Guikit.Settings_Panel.Capturing_Key (Model.Settings_Panel_View);
   end Settings_Capturing_Key;
