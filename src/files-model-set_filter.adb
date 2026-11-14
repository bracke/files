separate (Files.Model)
procedure Set_Filter
  (Model : in out Window_Model;
   Text  : String) is
begin
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Filter.Text := To_Unbounded_String (Text);
   Invalidate_Visible (Model);
   Model.Filter.Cursor := Text'Length;
   Model.Main_View_Scroll := 0;
   Reconcile_Selection (Model);
end Set_Filter;
