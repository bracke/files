separate (Files.Model)
procedure Settings_Cancel_Capture (Model : in out Window_Model) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
end Settings_Cancel_Capture;
