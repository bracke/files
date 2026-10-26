separate (Files.Model)
function Label_Picker_Highlight_Color
  (Model : Window_Model)
   return Files.Types.Color_Label is
begin
   return Files.Types.Label_For_Swatch (Model.Label_Picker_Swatch_Value);
end Label_Picker_Highlight_Color;
