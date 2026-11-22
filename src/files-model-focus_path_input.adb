separate (Files.Model)
procedure Focus_Path_Input
  (Model : in out Window_Model) is
begin
   Touch_Header (Model);
   Reset_Type_Ahead (Model);
   Model.Focus_Value := Files.UI_Types.Focus_Path_Input;
   Model.Tree_Panel.Keyboard := False;
   Model.Path_Input :=
     (Edit => (Text => Model.Current_Path_Value, Cursor => Length (Model.Current_Path_Value)), others => <>);
   Clear_Root_Selector_State (Model);
   Hide_Command_Palette (Model);
end Focus_Path_Input;
