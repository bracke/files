separate (Files.Model)
   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Panel_Open;
   end Tree_Panel_Is_Open;
