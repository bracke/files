separate (Files.Model)
   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Cancelled_Value;
   end Paste_Execution_Cancelled;
