separate (Files.Model)
procedure Focus_Path_Input
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Reset_Type_Ahead (Model);
   Model.Focus_Value := Files.Types.Focus_Path_Input;
   Model.Tree_Panel.Keyboard := False;
   Model.Path_Input := (Text => Model.Current_Path_Value, Cursor => Length (Model.Current_Path_Value), others => <>);
   Clear_Root_Selector_State (Model);
   Model.Command_Palette.Open := False;
   Guikit.Command_Palette.Reset (Model.Command_Palette.View);
end Focus_Path_Input;
