separate (Files.Model)
procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is
begin
   Touch (Model);
   Guikit.Settings_Panel.Cycle_Choice (Model.Settings_Panel_View, Forward);
end Settings_Cycle_Choice;
