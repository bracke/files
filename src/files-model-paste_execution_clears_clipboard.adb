separate (Files.Model)
   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Clears_Clip_Value;
   end Paste_Execution_Clears_Clipboard;
