with Guikit.Utf8.Editing;
separate (Files.Model)
function Rename_Delete
  (Model    : in out Window_Model;
   Backward : Boolean;
   By_Word  : Boolean := False)
   return Boolean
is
   Changed : Boolean := False;
begin
   for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
      declare
         Field      : Rename_Field := Model.Rename.Fields.Element (Index);
         Text       : constant String := To_String (Field.Value);
         New_Text   : Unbounded_String;
         New_Cursor : Natural;
      begin
         Guikit.Utf8.Editing.Delete_At (Text, Field.Cursor, Backward, By_Word, New_Text, New_Cursor);
         if Length (New_Text) /= Text'Length then
            Field.Value := New_Text;
            Field.Cursor := New_Cursor;
            Model.Rename.Fields.Replace_Element (Index, Field);
            Sync_Temporary_From_Field (Model, Field);
            Changed := True;
         end if;
      end;
   end loop;

   --  A key that deleted nothing changes nothing to redraw.
   if Changed then
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   end if;
   return Changed;
end Rename_Delete;
