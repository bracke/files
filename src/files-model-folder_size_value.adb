separate (Files.Model)
   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result is
      Key : constant UString := To_Unbounded_String (Path);
   begin
      if Model.Folder_Sizes.Contains (Key) then
         return Model.Folder_Sizes.Element (Key);
      else
         return (others => <>);
      end if;
   end Folder_Size_Value;
