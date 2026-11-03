separate (Files.Model)
procedure Clear_Filter
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Set_Filter (Model, "");
   Model.Search_Scope_Value := Files.Types.Filter_Here;
   Model.Search_Results_Active := False;
   Invalidate_Visible (Model);
end Clear_Filter;
