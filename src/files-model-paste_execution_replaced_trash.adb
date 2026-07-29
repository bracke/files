separate (Files.Model)
   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Replaced_Trash_Value;
   end Paste_Execution_Replaced_Trash;
