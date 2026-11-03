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
   Touch_Selection (Model);
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
      Rows : Natural_Vectors.Vector;
      Position : Natural := 0;

      procedure Note (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
         pragma Unreferenced (Item, Selected);
      begin
         Position := Position + 1;
         if Position in First .. Last then
            --  Rows are distinct and the list was cleared, so append directly
            --  rather than pay Add_Selected_Index's duplicate scan.
            Rows.Append (if Item_Index /= 0 then Item_Index else Temporary_Item_Index);
         end if;
      end Note;
   begin
      For_Each_Visible_Row (Model, Note'Access);
      Model.Selected_Item_Indexes := Rows;
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
