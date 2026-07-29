separate (Files.Model)
   function Tree_Node_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Files.Folder_Tree.Node_Count (Model.Folder_Tree_Value);
   end Tree_Node_Count;
