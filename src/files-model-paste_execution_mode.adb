separate (Files.Model)
   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Exec_Mode_Value;
   end Paste_Execution_Mode;
