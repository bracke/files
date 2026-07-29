separate (Files.Model)
   function Redo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Redo_Stack.Is_Empty;
   end Redo_Available;
