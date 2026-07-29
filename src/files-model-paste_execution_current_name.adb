separate (Files.Model)
   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_Current_Value);
   end Paste_Execution_Current_Name;
