separate (Files.Model)
procedure Move_Label_Picker_Highlight
  (Model : in out Window_Model;
   Delta_Value : Integer) is
begin
   Touch (Model);
   Model.Label_Picker.Swatch :=
     Integer'Max (1, Integer'Min (Files.Types.Swatch_Count, Model.Label_Picker.Swatch + Delta_Value));
end Move_Label_Picker_Highlight;
