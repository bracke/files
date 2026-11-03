separate (Files.Model)
procedure Set_Paste_Conflict_Policy
  (Model  : in out Window_Model;
   Policy : Files.Paste.Conflict_Policy) is
begin
   Touch (Model);
   Model.Paste_Conflict.Policy := Policy;
end Set_Paste_Conflict_Policy;
