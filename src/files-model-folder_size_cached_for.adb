separate (Files.Model)
   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean is
   begin
      return Model.Folder_Sizes.Contains (To_Unbounded_String (Path));
   end Folder_Size_Cached_For;
