separate (Files.Model)
procedure Set_Selection_Grid_Columns
  (Model   : in out Window_Model;
   Columns : Positive) is
begin
   --  Called before every key dispatch; an unconditional bump invalidated
   --  the render cache and forced a full snapshot rebuild per keystroke.
   if Model.Selection_Columns = Columns then
      return;
   end if;
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Selection_Columns := Columns;
end Set_Selection_Grid_Columns;
