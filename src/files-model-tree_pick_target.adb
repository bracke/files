separate (Files.Model)
   function Tree_Pick_Target
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Tree_Pick_Target_Value);
   end Tree_Pick_Target;
