separate (Files.Model)
procedure Set_Selected_Item_Extra
  (Model : in out Window_Model;
   Token : String)
is
   Idx : constant Natural := Model.Selected_Item_Index;
begin
   if not Selected_Item_Needs_Extra (Model) then
      return;
   end if;
   declare
      Item : Files.File_System.Directory_Item := Model.Items.Element (Idx);
   begin
      Item.Filetype_Extra := To_Unbounded_String (Token);
      Item.Filetype_Extra_Loaded := True;
      if Token /= "" then
         Model.Revision_Value := Model.Revision_Value + 1;
      end if;
      Model.Items.Replace_Element (Idx, Item);
   end;
end Set_Selected_Item_Extra;
