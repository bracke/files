separate (Files.Model)
procedure Select_Visible_Range
  (Model        : in out Window_Model;
   Anchor_Index : Positive;
   Target_Index : Positive)
is
   Count : constant Natural := Visible_Count (Model);
   First : Natural;
   Last  : Natural;

begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Reset_Type_Ahead (Model);
   if Count = 0
     or else Natural (Anchor_Index) > Count
     or else Natural (Target_Index) > Count
   then
      Clear_Selection (Model);
      return;
   end if;

   First := Natural'Min (Natural (Anchor_Index), Natural (Target_Index));
   Last := Natural'Max (Natural (Anchor_Index), Natural (Target_Index));

   Model.Selected_Item_Indexes.Clear;
   declare
      --  Map rows to items in one pass; a per-row scan made a long
      --  shift-click range quadratic.
      Rows : constant Visible_Row_Vectors.Vector := Visible_Rows (Model);
   begin
      for Visible_Index in First .. Natural'Min (Last, Natural (Rows.Length)) loop
         --  Rows are distinct and the list was just cleared, so append
         --  directly rather than pay Add_Selected_Index's duplicate scan.
         Model.Selected_Item_Indexes.Append
           (if Rows (Visible_Index).Item_Index /= 0 then Rows (Visible_Index).Item_Index
            else Temporary_Item_Index);
      end loop;
   end;

   Model.Selected_Item_Index := Visible_To_Item_Index (Model, Target_Index);
   if Model.Selected_Item_Index = 0
     and then Temporary_Is_Visible (Model)
     and then Natural (Target_Index) = Count
   then
      Model.Selected_Item_Index := Temporary_Item_Index;
   end if;
   Model.Info_Pane_Scroll := 0;
   Reconcile_Rename_With_Selection (Model);
end Select_Visible_Range;
