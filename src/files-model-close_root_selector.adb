separate (Files.Model)
procedure Close_Root_Selector
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Clear_Root_Selector_State (Model);
end Close_Root_Selector;
