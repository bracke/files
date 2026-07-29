separate (Files.Model)
   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target is
   begin
      return Model.Focus_Value;
   end Focus;
