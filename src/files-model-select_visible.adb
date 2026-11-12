separate (Files.Model)
procedure Select_Visible
  (Model         : in out Window_Model;
   Visible_Index : Positive) is
begin
   Touch_Selection (Model);
   Reset_Type_Ahead (Model);
   Select_Visible_Internal (Model, Visible_Index);
   Note_Range_Anchor (Model, Visible_Index);
end Select_Visible;
