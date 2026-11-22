separate (Files.Model)
procedure Set_Main_View_Scroll_Lines
  (Model : in out Window_Model;
   Lines : Natural) is
begin
   if Model.Main_View_Scroll = Lines then
      return;
   end if;

   Support.Touch_Scroll (Model);
   Model.Main_View_Scroll := Lines;
end Set_Main_View_Scroll_Lines;
