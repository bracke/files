separate (Files.Model)
   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive is
   begin
      return Model.Selection_Columns;
   end Selection_Grid_Columns;
