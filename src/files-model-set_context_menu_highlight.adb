separate (Files.Model)
procedure Set_Context_Menu_Highlight
  (Model : in out Window_Model;
   Row   : Natural) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Context_Menu.Highlight := Row;
end Set_Context_Menu_Highlight;
