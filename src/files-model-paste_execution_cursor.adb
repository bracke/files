separate (Files.Model)
   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Cursor_Value;
   end Paste_Execution_Cursor;
