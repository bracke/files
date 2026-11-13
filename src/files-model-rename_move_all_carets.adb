with Guikit.Utf8.Editing;
separate (Files.Model)
function Rename_Move_All_Carets
  (Model     : in out Window_Model;
   Direction : Guikit.Input.Navigation_Direction;
   By_Word   : Boolean := False)
   return Boolean
is
   Backward : constant Boolean :=
     Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
   Changed  : Boolean := False;
begin
   for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
      declare
         Field      : Rename_Field := Model.Rename.Fields.Element (Index);
         Text       : constant String := To_String (Field.Value);
         New_Cursor : Natural := Field.Cursor;
      begin
         if By_Word then
            New_Cursor :=
              (if Backward then Guikit.Utf8.Editing.Previous_Word_Boundary (Text, Field.Cursor)
               else Guikit.Utf8.Editing.Next_Word_Boundary (Text, Field.Cursor));
         elsif Backward then
            if Field.Cursor > 0 then
               New_Cursor := Guikit.Utf8.Editing.Previous_Boundary (Text, Field.Cursor);
            end if;
         elsif Field.Cursor < Text'Length then
            New_Cursor := Guikit.Utf8.Editing.Next_Boundary (Text, Field.Cursor);
         end if;

         if New_Cursor /= Field.Cursor then
            Field.Cursor := New_Cursor;
            Model.Rename.Fields.Replace_Element (Index, Field);
            Changed := True;
         end if;
      end;
   end loop;

   --  A key that moved no caret changes nothing to redraw.
   if Changed then
      Touch (Model);
   end if;
   return Changed;
end Rename_Move_All_Carets;
