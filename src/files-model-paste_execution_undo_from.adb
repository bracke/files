separate (Files.Model)
   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Undo_From_Value;
   end Paste_Execution_Undo_From;
