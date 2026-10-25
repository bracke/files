separate (Files.Operations)
procedure Apply_Ui_State
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model) is
begin
   Files.Model.Set_View_Mode (Model, Settings.Default_View);
   Files.Model.Apply_Sort (Model, Settings.Sort_Field_Value, Settings.Sort_Ascending);
end Apply_Ui_State;
