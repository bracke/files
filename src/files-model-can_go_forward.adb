separate (Files.Model)
   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Forward_History.Is_Empty;
   end Can_Go_Forward;
