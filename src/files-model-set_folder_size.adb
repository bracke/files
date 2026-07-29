separate (Files.Model)
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Folder_Sizes.Include (To_Unbounded_String (Path), Value);
   end Set_Folder_Size;
