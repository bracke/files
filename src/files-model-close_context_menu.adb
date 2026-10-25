separate (Files.Model)
procedure Close_Context_Menu
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Context_Menu := (others => <>);
end Close_Context_Menu;
