separate (Files.Model)
procedure Move_Sort_Menu_Highlight
  (Model : in out Window_Model;
   Delta_Value : Integer) is
   Current : constant Natural :=
     (if Model.Sort_Menu_Highlight_Value = 0 then 1 else Model.Sort_Menu_Highlight_Value);
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Sort_Menu_Highlight_Value :=
     Integer'Max (1, Integer'Min (5, Current + Delta_Value));
end Move_Sort_Menu_Highlight;
