separate (Files.Model)
   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Done_Value;
   end Paste_Execution_Done;
