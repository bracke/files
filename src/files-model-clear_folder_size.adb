separate (Files.Model)
   procedure Clear_Folder_Size
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Folder_Sizes.Clear;
   end Clear_Folder_Size;
