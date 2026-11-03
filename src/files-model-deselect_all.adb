separate (Files.Model)
procedure Deselect_All
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Clear_Selection (Model);
end Deselect_All;
