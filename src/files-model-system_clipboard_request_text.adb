separate (Files.Model)
   function System_Clipboard_Request_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.System_Clipboard_Request_Value);
   end System_Clipboard_Request_Text;
