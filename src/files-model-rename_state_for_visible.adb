separate (Files.Model)
   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
   is
      Field_Index : constant Natural :=
        (if Model.Rename_Active then Find_Rename_Field (Model, Visible_Index) else 0);
   begin
      if Field_Index = 0 then
         Active := False;
         Value  := Null_Unbounded_String;
         Cursor := 0;
      else
         declare
            Field : constant Rename_Field := Model.Rename_Fields.Element (Field_Index);
         begin
            Active := True;
            Value  := Field.Value;
            Cursor := Field.Cursor;
         end;
      end if;
   end Rename_State_For_Visible;
