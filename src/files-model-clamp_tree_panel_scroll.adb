separate (Files.Model)
procedure Clamp_Tree_Panel_Scroll
  (Model : in out Window_Model)
is
   Count : constant Natural :=
     Files.Folder_Tree.Visible_Row_Count (Model.Folder_Tree_Value);
   Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
begin
   Model.Tree_Panel_Scroll := Natural'Min (Model.Tree_Panel_Scroll, Maximum);
end Clamp_Tree_Panel_Scroll;
