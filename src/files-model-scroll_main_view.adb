separate (Files.Model)
   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Main_View_Scroll then
               Model.Main_View_Scroll := 0;
            else
               Model.Main_View_Scroll := Model.Main_View_Scroll - Step;
            end if;
         end;
      else
         Model.Main_View_Scroll := Saturating_Add (Model.Main_View_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Main_View;
