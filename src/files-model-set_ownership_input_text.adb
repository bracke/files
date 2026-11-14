separate (Files.Model)
procedure Set_Ownership_Input_Text
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.Ownership_Input.Edit.Text := To_Unbounded_String (Text);
   Model.Ownership_Input.Edit.Cursor := Text'Length;
end Set_Ownership_Input_Text;
