separate (Files.Model)
procedure Set_Main_View_Scroll_Lines
  (Model : in out Window_Model;
   Lines : Natural) is
begin
   if Model.Main_View_Scroll = Lines then
      return;
   end if;

   Model.Scroll_Revision_Value := Model.Scroll_Revision_Value + 1;
   Model.Main_View_Scroll := Lines;
end Set_Main_View_Scroll_Lines;
