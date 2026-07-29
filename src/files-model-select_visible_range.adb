separate (Files.Model)
   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive)
   is
      Count : constant Natural := Visible_Count (Model);
      First : Natural;
      Last  : Natural;

      procedure Add_Visible_Index (Visible_Index : Positive) is
         Item_Index : Natural := Visible_To_Item_Index (Model, Visible_Index);
      begin
         if Item_Index = 0
           and then Temporary_Is_Visible (Model)
           and then Visible_Index = Count
         then
            Item_Index := Temporary_Item_Index;
         end if;

         Add_Selected_Index (Model, Item_Index);
      end Add_Visible_Index;
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
      for Visible_Index in First .. Last loop
         Add_Visible_Index (Positive (Visible_Index));
      end loop;

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
