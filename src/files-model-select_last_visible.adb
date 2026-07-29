separate (Files.Model)
   procedure Select_Last_Visible
     (Model : in out Window_Model)
   is
      Count : constant Natural := Visible_Count (Model);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Count = 0 then
         Clear_Selection (Model);
      else
         Select_Visible (Model, Positive (Count));
      end if;
   end Select_Last_Visible;
