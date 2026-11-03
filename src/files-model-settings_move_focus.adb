separate (Files.Model)
procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Move_Focus (Model.Settings_Panel_View, Delta_Rows);
end Settings_Move_Focus;
