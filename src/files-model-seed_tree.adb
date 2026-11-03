separate (Files.Model)
procedure Seed_Tree
  (Model : in out Window_Model;
   Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
begin
   Touch (Model);
   Model.Tree_Panel_Scroll := 0;
   Files.Folder_Tree.Seed (Model.Folder_Tree_Value, Roots);
end Seed_Tree;
