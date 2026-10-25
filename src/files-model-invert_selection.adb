separate (Files.Model)
procedure Invert_Selection
  (Model : in out Window_Model)
is
   Primary : Natural := 0;
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Reset_Type_Ahead (Model);

   if Model.Items.Is_Empty then
      Reconcile_Rename_With_Selection (Model);
      return;
   end if;

   declare
      --  Rebuild in one pass: visible items flip, hidden ones keep their
      --  state, and the pending create row's marker survives.
      Was_Selected : constant Selection_Flags := Selected_Flags (Model);
      Temporary    : constant Boolean :=
        Model.Selected_Item_Indexes.Contains (Temporary_Item_Index);
   begin
      Model.Selected_Item_Indexes.Clear;
      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items (Index)) /= Was_Selected (Index) then
            Model.Selected_Item_Indexes.Append (Natural (Index));
         end if;
      end loop;
      if Temporary then
         Model.Selected_Item_Indexes.Append (Temporary_Item_Index);
      end if;
   end;

   --  Items are stored in visible order, so the lowest selected index is
   --  the first visible selected item and makes a deterministic primary.
   for Selected of Model.Selected_Item_Indexes loop
      if Primary = 0 or else Selected < Primary then
         Primary := Selected;
      end if;
   end loop;

   Model.Selected_Item_Index := Primary;
   Model.Info_Pane_Scroll := 0;
   Reconcile_Rename_With_Selection (Model);
end Invert_Selection;
