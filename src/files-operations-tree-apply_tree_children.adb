with Files.Folder_Tree;
with Files.Model.Tree_Panel;

separate (Files.Operations.Tree)
procedure Apply_Tree_Children
  (Model      : in out Files.Model.Window_Model;
   Node_Index : Positive;
   Load       : Files.File_System.Directory_Load_Result)
is
   Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
begin
   if not Load.Success then
      Files.Model.Tree_Panel.Load_Failed (Model, Node_Index);
      Files.Model.Set_Error (Model, To_String (Load.Error_Key));
      return;
   end if;
   for Item of Load.Items loop
      if Item.Kind = Files.Types.Directory_Item then
         Children.Append
           (Files.Folder_Tree.Entry_Seed'
              (Path => Item.Full_Path,
               Name => Item.Name));
      end if;
   end loop;
   Files.Model.Tree_Panel.Set_Children (Model, Node_Index, Children);
end Apply_Tree_Children;
