separate (Files.Model)
procedure Focus_Rename_Input
  (Model : in out Window_Model) is
begin
   Touch (Model);
   if Model.Rename.Active then
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
      Clear_Root_Selector_State (Model);
      Hide_Command_Palette (Model);
   end if;
end Focus_Rename_Input;
