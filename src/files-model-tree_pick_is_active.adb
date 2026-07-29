separate (Files.Model)
   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Pick_Mode_Value /= Pick_None;
   end Tree_Pick_Is_Active;
