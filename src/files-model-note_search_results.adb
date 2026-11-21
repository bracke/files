with Files.UI_Types;
separate (Files.Model)
procedure Note_Search_Results
  (Model : in out Window_Model;
   Scope : Files.UI_Types.Search_Scope) is
begin
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Search_Scope_Value := Scope;
   Model.Search_Results_Active := Scope /= Files.UI_Types.Filter_Here;
   Model.Results_Hide_Hidden := False;
   Invalidate_Visible (Model);
end Note_Search_Results;
