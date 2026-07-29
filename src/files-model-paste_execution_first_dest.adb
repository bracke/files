separate (Files.Model)
   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_First_Dest_Value);
   end Paste_Execution_First_Dest;
