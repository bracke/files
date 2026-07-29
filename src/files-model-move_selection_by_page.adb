separate (Files.Model)
   procedure Move_Selection_By_Page
     (Model     : in out Window_Model;
      Page_Rows : Positive;
      Down      : Boolean)
   is
      Count   : constant Natural := Visible_Count (Model);
      Current : constant Natural := Selected_Index (Model);
      Stride  : constant Natural :=
        Natural'Max (1, Natural'Min (Natural (Model.Selection_Columns), Natural'Max (1, Count)));
      Step    : constant Natural := Natural (Page_Rows) * Stride;
      Next    : Natural;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Count = 0 then
         Clear_Selection (Model);
         return;
      elsif Current = 0 then
         Select_Visible (Model, 1);
         return;
      end if;

      if Down then
         if Current + Step >= Count then
            Next := Count;
         else
            Next := Current + Step;
         end if;
      else
         if Current <= Step then
            Next := 1;
         else
            Next := Current - Step;
         end if;
      end if;

      Select_Visible (Model, Positive (Next));
   end Move_Selection_By_Page;
