separate (Files.Model)
   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Search_Results_Active;
   end Search_Results_Are_Active;
