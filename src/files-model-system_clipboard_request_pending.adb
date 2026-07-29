separate (Files.Model)
   function System_Clipboard_Request_Pending
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.System_Clipboard_Request_Pending;
   end System_Clipboard_Request_Pending;
