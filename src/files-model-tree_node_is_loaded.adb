separate (Files.Model)
   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      return Files.Folder_Tree.Node_Is_Loaded (Model.Folder_Tree_Value, Index);
   end Tree_Node_Is_Loaded;
