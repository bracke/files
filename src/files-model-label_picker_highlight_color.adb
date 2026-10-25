separate (Files.Model)
function Label_Picker_Highlight_Color
  (Model : Window_Model)
   return Files.Types.Color_Label is
begin
   if Model.Label_Picker_Swatch_Value in 1 .. 7 then
      return Files.Types.Color_Label'Val (Model.Label_Picker_Swatch_Value);
   else
      return Files.Types.No_Label;
   end if;
end Label_Picker_Highlight_Color;
