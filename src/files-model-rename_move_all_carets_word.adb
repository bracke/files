separate (Files.Model)
   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename_Fields.Element (Index);
            Text       : constant String := To_String (Field.Value);
            New_Cursor : constant Natural :=
              (if Backward then Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor)
               else Files.UTF8.Next_Word_Boundary (Text, Field.Cursor));
         begin
            if New_Cursor /= Field.Cursor then
               Field.Cursor := New_Cursor;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Move_All_Carets_Word;
