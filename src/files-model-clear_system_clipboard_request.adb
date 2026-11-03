separate (Files.Model)
procedure Clear_System_Clipboard_Request
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.System_Clipboard_Request_Value := Null_Unbounded_String;
   Model.System_Clipboard_Request_Pending := False;
end Clear_System_Clipboard_Request;
