separate (Files.Model)
procedure Ensure_Tree_Row_Visible
  (Model       : in out Window_Model;
   Visible_Row : Positive;
   Page_Rows   : Natural)
is
   Count : constant Natural :=
     Files.Folder_Tree.Visible_Row_Count (Model.Folder_Tree_Value);
   Maximum : constant Natural :=
     (if Count > Page_Rows then Count - Page_Rows else 0);
   Current : constant Natural :=
     Natural'Min (Tree_Panel_Scroll_Rows (Model), Maximum);
   Target  : constant Natural := Visible_Row - 1;
   Wanted  : Natural := Current;
begin
   if not Model.Tree_Panel_Open
     or else Page_Rows = 0
     or else Count = 0
     or else Visible_Row > Count
   then
      return;
   end if;

   if Target < Current then
      Wanted := Target;
   elsif Target - Current >= Page_Rows then
      Wanted := Target - Page_Rows + 1;
   end if;
   Wanted := Natural'Min (Wanted, Maximum);

   if Model.Tree_Panel_Scroll /= Wanted then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Scroll := Wanted;
   end if;
end Ensure_Tree_Row_Visible;
