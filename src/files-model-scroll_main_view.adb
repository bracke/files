separate (Files.Model)
procedure Scroll_Main_View
  (Model : in out Window_Model;
   Lines : Integer)
is
   Current : constant Natural := Model.Main_View_Scroll;
   Wanted  : Natural;
begin
   if Lines = 0 then
      return;
   elsif Lines < 0 then
      declare
         Step : constant Natural := Scroll_Step (Lines);
      begin
         Wanted := (if Step >= Current then 0 else Current - Step);
      end;
   else
      Wanted := Saturating_Add (Current, Scroll_Step (Lines));
   end if;

   if Wanted /= Current then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Main_View_Scroll := Wanted;
   end if;
end Scroll_Main_View;
