separate (Files.Model)
   function Quick_Look_Content_Of
     (Model : Window_Model)
      return Files.Quick_Look.Quick_Look_Content is
   begin
      return Model.Quick_Look_Content_Value;
   end Quick_Look_Content_Of;
