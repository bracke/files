separate (Files.Model)
   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      return Files.Folder_Tree.Node_Path (Model.Folder_Tree_Value, Index);
   end Tree_Node_Path;
