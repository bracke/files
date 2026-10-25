separate (Files.Model)
function Settings_Focused_Key (Model : Window_Model) return String is
begin
   return Guikit.Settings_Panel.Focused_Key (Model.Settings_Panel_View);
end Settings_Focused_Key;
