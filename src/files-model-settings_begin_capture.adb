separate (Files.Model)
procedure Settings_Begin_Capture (Model : in out Window_Model) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Begin_Capture (Model.Settings_Panel_View);
end Settings_Begin_Capture;
