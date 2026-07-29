separate (Files.Model)
   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Open_With_Targets_Value;
   end Open_With_Targets;
