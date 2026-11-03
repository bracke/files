separate (Files.Model)
procedure Set_Path_Input_Text
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.Path_Input_Value := To_Unbounded_String (Text);
   Model.Path_Input_Cursor := Text'Length;
   Model.Path_Input_Valid := True;
   Model.Path_Input_Error := Null_Unbounded_String;
end Set_Path_Input_Text;
