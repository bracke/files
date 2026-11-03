separate (Files.Model)
procedure Close_Context_Menu
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Context_Menu := (others => <>);
end Close_Context_Menu;
