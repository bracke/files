separate (Files.Model)
   function Home_Path
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Home_Path_Value);
   end Home_Path;
