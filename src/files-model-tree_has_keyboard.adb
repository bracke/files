separate (Files.Model)
function Tree_Has_Keyboard
  (Model : Window_Model)
   return Boolean is
begin
   return Model.Tree_Keyboard_Value
     and then Model.Tree_Panel_Open
     and then Model.Tree_Pick_Mode_Value = Pick_None
     and then Model.Focus_Value = Files.Types.Focus_None;
end Tree_Has_Keyboard;
