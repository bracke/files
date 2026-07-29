separate (Files.Model)
   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is
   begin
      return Model.Paste_Exec_Actions_Value.Element (Index);
   end Paste_Execution_Action;
