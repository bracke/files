separate (Files.Model)
procedure Set_Paste_Conflict_Override
  (Model    : in out Window_Model;
   Index    : Positive;
   Decision : Files.Paste.Item_Decision) is
begin
   Touch (Model);
   if Index <= Natural (Model.Paste_Conflict.Overrides.Length) then
      Model.Paste_Conflict.Overrides.Replace_Element (Index, Decision);
   end if;
end Set_Paste_Conflict_Override;
