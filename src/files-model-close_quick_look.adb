separate (Files.Model)
procedure Close_Quick_Look
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Reset_Quick_Look (Model);
end Close_Quick_Look;
