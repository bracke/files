with Files.UTF8;
separate (Files.Model)
function Rename_Delete
  (Model    : in out Window_Model;
   Backward : Boolean;
   By_Word  : Boolean := False)
   return Boolean
is
   Changed : Boolean := False;
begin
   for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
      declare
         Field : Rename_Field := Model.Rename_Fields.Element (Index);
         Text  : constant String := To_String (Field.Value);
      begin
         if Backward and then Field.Cursor > 0 and then Text'Length > 0 then
            declare
               Boundary : constant Natural :=
                 (if By_Word then Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor)
                  else Files.UTF8.Previous_Boundary (Text, Field.Cursor));
            begin
               if Boundary < Field.Cursor then
                  Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Boundary, Field.Cursor));
                  Field.Cursor := Boundary;
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end if;
            end;
         elsif not Backward and then Field.Cursor < Text'Length then
            declare
               Boundary : constant Natural :=
                 (if By_Word then Files.UTF8.Next_Word_Boundary (Text, Field.Cursor)
                  else Files.UTF8.Next_Boundary (Text, Field.Cursor));
            begin
               if Boundary > Field.Cursor then
                  Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Field.Cursor, Boundary));
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end if;
            end;
         end if;
      end;
   end loop;

   --  A key that deleted nothing changes nothing to redraw.
   if Changed then
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   end if;
   return Changed;
end Rename_Delete;
