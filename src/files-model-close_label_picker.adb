separate (Files.Model)
procedure Close_Label_Picker
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Label_Picker_Active := False;
end Close_Label_Picker;
