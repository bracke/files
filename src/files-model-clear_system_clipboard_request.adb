separate (Files.Model)
   procedure Clear_System_Clipboard_Request
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.System_Clipboard_Request_Value := Null_Unbounded_String;
      Model.System_Clipboard_Request_Pending := False;
   end Clear_System_Clipboard_Request;
