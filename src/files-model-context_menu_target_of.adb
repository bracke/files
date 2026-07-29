separate (Files.Model)
   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target is
   begin
      return Model.Context_Menu_Target_Value;
   end Context_Menu_Target_Of;
