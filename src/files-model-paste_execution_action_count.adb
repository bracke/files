separate (Files.Model)
   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Paste_Exec_Actions_Value.Length);
   end Paste_Execution_Action_Count;
