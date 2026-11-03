separate (Files.Model)
procedure Set_Search_Scope
  (Model : in out Window_Model;
   Scope : Files.Types.Search_Scope) is
begin
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   Model.Search_Scope_Value := Scope;
end Set_Search_Scope;
