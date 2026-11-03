separate (Files.Model)
procedure Clear_Search_Results
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Search_Scope_Value := Files.Types.Filter_Here;
   Model.Search_Results_Active := False;
   Invalidate_Visible (Model);
end Clear_Search_Results;
