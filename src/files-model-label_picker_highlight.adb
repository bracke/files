separate (Files.Model)
function Label_Picker_Highlight
  (Model : Window_Model)
   return Positive is
begin
   return Model.Label_Picker.Swatch;
end Label_Picker_Highlight;
