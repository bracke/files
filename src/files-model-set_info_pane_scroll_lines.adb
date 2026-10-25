separate (Files.Model)
procedure Set_Info_Pane_Scroll_Lines
  (Model : in out Window_Model;
   Lines : Natural) is
begin
   if Model.Info_Pane_Scroll = Lines then
      return;
   end if;

   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Info_Pane_Scroll := Lines;
end Set_Info_Pane_Scroll_Lines;
