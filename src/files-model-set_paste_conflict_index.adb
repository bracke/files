separate (Files.Model)
procedure Set_Paste_Conflict_Index
  (Model : in out Window_Model;
   Index : Positive) is
begin
   Touch (Model);
   Model.Paste_Conflict.Index := Index;
end Set_Paste_Conflict_Index;
