separate (Files.Model)
   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Active_Value;
   end Paste_Execution_Is_Active;
