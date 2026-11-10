separate (Files.Model)
procedure Set_Selected_Item_Extra
  (Model : in out Window_Model;
   Extra : Files.Extra_Info.Info)
is
   use type Files.Extra_Info.Kind;
   Idx : constant Natural := Model.Selected_Item_Index;
begin
   if not Selected_Item_Needs_Extra (Model) then
      return;
   end if;
   declare
      Item : Files.Items.Directory_Item := Model.Items.Element (Idx);
   begin
      Item.Filetype_Extra := Extra;
      Item.Filetype_Extra_Loaded := True;
      if Extra.Of_Kind /= Files.Extra_Info.None then
         Touch (Model);
      end if;
      Model.Items.Replace_Element (Idx, Item);
   end;
end Set_Selected_Item_Extra;
