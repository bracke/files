separate (Files.Model)
procedure Set_Context_Menu_Highlight
  (Model : in out Window_Model;
   Row   : Natural) is
begin
   Touch (Model);
   Model.Context_Menu.Highlight := Row;
end Set_Context_Menu_Highlight;
