separate (Files.Model)
   function Clipboard_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Clipboard_Paths_Value;
   end Clipboard_Paths;
