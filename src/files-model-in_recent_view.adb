separate (Files.Model)
   function In_Recent_View
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Recent_View_Active;
   end In_Recent_View;
