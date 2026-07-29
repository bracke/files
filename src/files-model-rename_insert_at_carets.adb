separate (Files.Model)
   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Text = "" then
         return False;
      end if;

      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Old   : constant String := To_String (Field.Value);
            Base  : constant Natural := Natural'Min (Field.Cursor, Old'Length);
         begin
            Field.Value := To_Unbounded_String (Insert_Text_At (Old, Base, Text));
            Field.Cursor := Base + Text'Length;
            Model.Rename_Fields.Replace_Element (Index, Field);
            Sync_Temporary_From_Field (Model, Field);
            Changed := True;
         end;
      end loop;

      return Changed;
   end Rename_Insert_At_Carets;
