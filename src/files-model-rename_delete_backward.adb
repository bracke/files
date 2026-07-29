separate (Files.Model)
   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Text  : constant String := To_String (Field.Value);
         begin
            if Field.Cursor > 0 and then Text'Length > 0 then
               declare
                  Previous : constant Natural := Files.UTF8.Previous_Boundary (Text, Field.Cursor);
               begin
                  Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Previous, Field.Cursor));
                  Field.Cursor := Previous;
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Backward;
