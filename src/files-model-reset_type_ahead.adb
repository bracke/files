separate (Files.Model)
procedure Reset_Type_Ahead
  (Model : in out Window_Model) is
begin
   Touch_Header (Model);
   Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
end Reset_Type_Ahead;
