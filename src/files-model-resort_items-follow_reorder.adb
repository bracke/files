separate (Files.Model.Resort_Items)
procedure Follow_Reorder is
begin
   declare
      --  The pending create row is selected through a marker, not an item
      --  index; keep it, or the row being named loses its highlight.
      Temporary_Selected : constant Boolean :=
        Model.Selected_Item_Indexes.Contains (Temporary_Item_Index);
   begin
      Model.Selected_Item_Indexes.Clear;
      for Path of Previous_Selection loop
         declare
            New_Index : constant Natural := Index_Of (Path);
         begin
            if New_Index /= 0 then
               Model.Selected_Item_Indexes.Append (New_Index);
            end if;
         end;
      end loop;
      if Temporary_Selected then
         Model.Selected_Item_Indexes.Append (Temporary_Item_Index);
      end if;
   end;

   if not Primary_Sentinel then
      Model.Selected_Item_Index := Index_Of (Primary_Path);
   end if;

   --  Remap each rename field to its item's new index, preserving the
   --  temporary field and dropping fields whose item vanished.
   declare
      Rebuilt : Rename_Field_Vectors.Vector;
      Cursor  : Positive := Rename_Old_Paths.First_Index;
   begin
      for Field of Model.Rename.Fields loop
         declare
            Old_Path  : constant Unbounded_String := Rename_Old_Paths.Element (Cursor);
            New_Field : Rename_Field := Field;
         begin
            if Field.Item_Index = Temporary_Item_Index then
               Rebuilt.Append (Field);
            else
               declare
                  New_Index : constant Natural := Index_Of (Old_Path);
               begin
                  if New_Index /= 0 then
                     New_Field.Item_Index := New_Index;
                     Rebuilt.Append (New_Field);
                  end if;
               end;
            end if;
         end;
         Cursor := Cursor + 1;
      end loop;
      Model.Rename.Fields := Rebuilt;
   end;
end Follow_Reorder;
