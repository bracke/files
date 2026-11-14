separate (Files.Model)
procedure Set_Path_Input_Text
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.Path_Input := (Edit => (Text => To_Unbounded_String (Text), Cursor => Text'Length), others => <>);
end Set_Path_Input_Text;
