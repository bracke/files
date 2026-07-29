separate (Files.Model)
   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope is
   begin
      return Model.Search_Scope_Value;
   end Search_Scope_Of;
