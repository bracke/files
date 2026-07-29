separate (Files.Model)
   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Conflict_Mode_Value;
   end Paste_Conflict_Mode;
