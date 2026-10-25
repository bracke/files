separate (Files.Model)
procedure Set_Tree_Panel_Scroll_Rows
  (Model : in out Window_Model;
   Rows  : Natural)
is
   Count : constant Natural :=
     Files.Folder_Tree.Visible_Row_Count (Model.Folder_Tree_Value);
   Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
   Value   : constant Natural := Natural'Min (Rows, Maximum);
begin
   if not Model.Tree_Panel_Open or else Model.Tree_Panel_Scroll = Value then
      return;
   end if;

   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Tree_Panel_Scroll := Value;
end Set_Tree_Panel_Scroll_Rows;
