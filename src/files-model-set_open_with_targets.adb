separate (Files.Model)
procedure Set_Open_With_Targets
  (Model   : in out Window_Model;
   Targets : Files.Types.String_Vectors.Vector) is
begin
   Touch (Model);
   Model.Open_With_Targets_Value := Targets;
end Set_Open_With_Targets;
