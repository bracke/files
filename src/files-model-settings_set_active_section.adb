separate (Files.Model)
procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Set_Active_Section (Model.Settings_Panel_View, Ordinal);
end Settings_Set_Active_Section;
