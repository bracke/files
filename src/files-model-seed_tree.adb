separate (Files.Model)
   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Seed (Model.Folder_Tree_Value, Roots);
   end Seed_Tree;
