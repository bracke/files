separate (Files.Model)
procedure Scroll_Tree_Panel
  (Model : in out Window_Model;
   Rows  : Integer)
is
   Current : constant Natural := Tree_Panel_Scroll_Rows (Model);
   Count   : constant Natural :=
     Files.Folder_Tree.Visible_Row_Count (Model.Folder_Tree_Value);
   Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
   Step    : Natural;
   Wanted  : Natural;
begin
   if not Model.Tree_Panel_Open or else Rows = 0 then
      return;
   end if;

   if Rows < 0 then
      Step := (if Rows = Integer'First then Natural'Last else Natural (-Rows));
      Wanted := (if Step >= Current then 0 else Current - Step);
   else
      Step := Natural (Rows);
      Wanted := Natural'Min (Maximum, Saturating_Add (Current, Step));
   end if;

   --  Compare the stored value as well as its clamped public projection. A
   --  collapse can temporarily reduce the row count; the next scroll should
   --  normalize that stale offset rather than letting it resurface later.
   if Model.Tree_Panel_Scroll /= Wanted then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Scroll := Wanted;
   end if;
end Scroll_Tree_Panel;
