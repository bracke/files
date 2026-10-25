separate (Files.Model)
function Settings_Focused_Kind (Model : Window_Model) return Guikit.Settings_Panel.Field_Kind is
begin
   return Guikit.Settings_Panel.Focused_Kind (Model.Settings_Panel_View);
end Settings_Focused_Kind;
