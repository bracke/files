separate (Files.Model)
   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Settings_Pane_Open;
   end Settings_Pane_Is_Open;
