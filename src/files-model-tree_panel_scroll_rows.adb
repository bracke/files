separate (Files.Model)
function Tree_Panel_Scroll_Rows
  (Model : Window_Model)
   return Natural
is
   Count : constant Natural :=
     Files.Folder_Tree.Visible_Row_Count (Model.Folder_Tree_Value);
begin
   return
     (if Count = 0 then 0
      else Natural'Min (Model.Tree_Panel_Scroll, Count - 1));
end Tree_Panel_Scroll_Rows;
