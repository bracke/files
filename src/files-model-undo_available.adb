separate (Files.Model)
   function Undo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Undo_Stack.Is_Empty;
   end Undo_Available;
