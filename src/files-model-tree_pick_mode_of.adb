separate (Files.Model)
   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode is
   begin
      return Model.Tree_Pick_Mode_Value;
   end Tree_Pick_Mode_Of;
