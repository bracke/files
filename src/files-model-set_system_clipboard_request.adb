separate (Files.Model)
procedure Set_System_Clipboard_Request
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.System_Clipboard_Request_Value := To_Unbounded_String (Text);
   Model.System_Clipboard_Request_Pending := True;
end Set_System_Clipboard_Request;
