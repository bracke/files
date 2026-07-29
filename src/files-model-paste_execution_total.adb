separate (Files.Model)
   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Total_Value;
   end Paste_Execution_Total;
