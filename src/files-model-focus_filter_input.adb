separate (Files.Model)
procedure Focus_Filter_Input
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Reset_Type_Ahead (Model);
   Model.Focus_Value := Files.Types.Focus_Filter_Input;
   Model.Tree_Panel.Keyboard := False;
   Model.Filter.Cursor := Length (Model.Filter.Text);
   Clear_Root_Selector_State (Model);
   Hide_Command_Palette (Model);
end Focus_Filter_Input;
