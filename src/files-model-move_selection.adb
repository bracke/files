separate (Files.Model)
   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Count   : constant Natural := Visible_Count (Model);
      Current : constant Natural := Selected_Index (Model);
      Stride  : constant Natural :=
        Natural'Max (1, Natural'Min (Natural (Model.Selection_Columns), Natural'Max (1, Count)));
      Next    : Natural;

      function Last_In_Column
        (Column : Positive)
         return Natural
      is
         Candidate : Natural := Natural (Column);
      begin
         while Candidate + Stride <= Count loop
            Candidate := Candidate + Stride;
         end loop;

         return Candidate;
      end Last_In_Column;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Count = 0 then
         Clear_Selection (Model);
         return;
      elsif Current = 0 then
         Select_Visible (Model, 1);
         return;
      end if;

      case Direction is
         when Guikit.Input.Move_Left =>
            if Current = 1 then
               Next := Count;
            else
               Next := Current - 1;
            end if;
         when Guikit.Input.Move_Right =>
            if Current = Count then
               Next := 1;
            else
               Next := Current + 1;
            end if;
         when Guikit.Input.Move_Up =>
            if Current = 1 then
               Next := Count;
            elsif Current > Stride then
               Next := Current - Stride;
            else
               Next := Last_In_Column (Positive (Current));
            end if;
         when Guikit.Input.Move_Down =>
            if Current = Count then
               Next := 1;
            elsif Current + Stride <= Count then
               Next := Current + Stride;
            else
               Next := ((Current - 1) mod Stride) + 1;
            end if;
      end case;

      Select_Visible (Model, Positive (Next));
   end Move_Selection;
