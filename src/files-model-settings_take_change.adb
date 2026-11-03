separate (Files.Model)
function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is
begin
   Touch (Model);
   return Guikit.Settings_Panel.Take_Change (Model.Settings_Panel_View);
end Settings_Take_Change;
