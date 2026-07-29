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

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index)) then
            if Selection_Contains (Model, Natural (Index)) then
               Remove_Selected_Index (Model, Natural (Index));
            else
               Add_Selected_Index (Model, Natural (Index));
            end if;
         end if;
      end loop;

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
