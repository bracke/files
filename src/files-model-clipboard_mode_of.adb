separate (Files.Model)
   function Clipboard_Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is
   begin
      return Model.Clipboard_Mode_Value;
   end Clipboard_Mode_Of;
