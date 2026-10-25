separate (Files.Model)
procedure Rename_State_For_Item
  (Model      : Window_Model;
   Item_Index : Natural;
   Active     : out Boolean;
   Value      : out UString;
   Cursor     : out Natural) is
begin
   Active := False;
   Value  := Null_Unbounded_String;
   Cursor := 0;
   if not Model.Rename_Active then
      return;
   end if;
   --  Same match as Find_Rename_Field: zero is the pending create row.
   for Field of Model.Rename_Fields loop
      if Field.Item_Index = Item_Index then
         Active := True;
         Value  := Field.Value;
         Cursor := Field.Cursor;
         return;
      end if;
   end loop;
end Rename_State_For_Item;
