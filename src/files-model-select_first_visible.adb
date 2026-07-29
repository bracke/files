separate (Files.Model)
   procedure Select_First_Visible
     (Model : in out Window_Model)
   is
      Count : constant Natural := Visible_Count (Model);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Count = 0 then
         Clear_Selection (Model);
      else
         Select_Visible (Model, 1);
      end if;
   end Select_First_Visible;
