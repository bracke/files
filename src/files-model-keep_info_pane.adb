separate (Files.Model)
procedure Keep_Info_Pane
  (Model      : in out Window_Model;
   Previous   : Files.Items.Directory_Item;
   Scroll     : Natural;
   Keep_Extra : Boolean)
is
   Idx : constant Natural := Model.Selected_Item_Index;
begin
   if Idx = 0
     or else Idx > Natural (Model.Items.Length)
     or else Length (Previous.Full_Path) = 0
     or else Model.Items (Idx).Full_Path /= Previous.Full_Path
   then
      return;
   end if;
   Set_Info_Pane_Scroll_Lines (Model, Scroll);
   declare
      Item : Files.Items.Directory_Item := Model.Items.Element (Idx);
   begin
      --  The details depend on the item as listed (see Files.Extra_Info_Reader):
      --  the same facts read the same details.
      if Keep_Extra
        and then Previous.Filetype_Extra_Loaded
        and then not Item.Filetype_Extra_Loaded
        and then Files.Types."=" (Item.Kind, Previous.Kind)
        and then Item.Filetype = Previous.Filetype
        and then Item.Size_Available = Previous.Size_Available
        and then Item.Size = Previous.Size
        and then Item.Modified_Available = Previous.Modified_Available
        and then Ada.Calendar."=" (Item.Modified_Time, Previous.Modified_Time)
      then
         Item.Filetype_Extra := Previous.Filetype_Extra;
         Item.Filetype_Extra_Loaded := True;
         Model.Items.Replace_Element (Idx, Item);
         Touch (Model);
      end if;
   end;
end Keep_Info_Pane;
