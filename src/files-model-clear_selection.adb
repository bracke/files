separate (Files.Model)
   procedure Clear_Selection
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Selected_Item_Index := 0;
      Model.Selected_Item_Indexes.Clear;
      Model.Info_Pane_Scroll := 0;
      Reconcile_Rename_With_Selection (Model);
   end Clear_Selection;
