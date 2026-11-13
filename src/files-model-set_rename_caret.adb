with Guikit.Utf8.Editing;
separate (Files.Model)
procedure Set_Rename_Caret
  (Model         : in out Window_Model;
   Visible_Index : Natural;
   Position      : Natural) is
begin
   Touch (Model);
   if Visible_Index = 0 or else not Model.Rename.Active then
      return;
   end if;

   declare
      Field_Index : constant Natural := Find_Rename_Field (Model, Positive (Visible_Index));
   begin
      if Field_Index /= 0 then
         declare
            Field : Rename_Field := Model.Rename.Fields.Element (Field_Index);
         begin
            Field.Cursor := Guikit.Utf8.Editing.Boundary_At_Or_Before (To_String (Field.Value), Position);
            Model.Rename.Fields.Replace_Element (Field_Index, Field);
         end;
      end if;
   end;
end Set_Rename_Caret;
