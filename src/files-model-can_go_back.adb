separate (Files.Model)
   function Can_Go_Back
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Back_History.Is_Empty;
   end Can_Go_Back;
