separate (Files.Model)
procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Set_Captured_Shortcut (Model.Settings_Panel_View, Text);
end Settings_Set_Captured_Shortcut;
