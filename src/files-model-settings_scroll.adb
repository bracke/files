separate (Files.Model)
procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Scroll (Model.Settings_Panel_View, Lines);
end Settings_Scroll;
