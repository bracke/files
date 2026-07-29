separate (Files.Model)
   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode is
   begin
      return Model.Command_Palette_Mode;
   end Command_Palette_Mode_Of;
