separate (Files.Model)
   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Label_Picker_Active;
   end Label_Picker_Is_Open;
