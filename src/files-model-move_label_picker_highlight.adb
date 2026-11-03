separate (Files.Model)
procedure Move_Label_Picker_Highlight
  (Model : in out Window_Model;
   Delta_Value : Integer) is
begin
   Touch (Model);
   Model.Label_Picker_Swatch_Value :=
     Integer'Max (1, Integer'Min (8, Model.Label_Picker_Swatch_Value + Delta_Value));
end Move_Label_Picker_Highlight;
