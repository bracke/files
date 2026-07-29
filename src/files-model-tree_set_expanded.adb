separate (Files.Model)
   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Set_Expanded (Model.Folder_Tree_Value, Index, Expanded);
   end Tree_Set_Expanded;
