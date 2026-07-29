separate (Files.Model)
   procedure Select_All_Visible
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Indexes.Clear;
      Model.Selected_Item_Index := 0;

      if Model.Items.Is_Empty then
         Reconcile_Rename_With_Selection (Model);
         return;
      end if;

      for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
         if Item_Is_Visible (Model, Model.Items.Element (Index)) then
            Add_Selected_Index (Model, Natural (Index));
            if Model.Selected_Item_Index = 0 then
               Model.Selected_Item_Index := Natural (Index);
            end if;
         end if;
      end loop;

      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Select_All_Visible;
