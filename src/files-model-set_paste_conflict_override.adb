separate (Files.Model)
   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Index <= Natural (Model.Paste_Conflict_Overrides_Value.Length) then
         Model.Paste_Conflict_Overrides_Value.Replace_Element (Index, Decision);
      end if;
   end Set_Paste_Conflict_Override;
