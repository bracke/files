separate (Files.Model)
   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode is
   begin
      return Model.View_Value;
   end View_Mode_Of;
