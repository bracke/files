separate (Files.Controller)
   function Delete_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Direction : Delete_Direction;
      By_Word   : Boolean)
      return Controller_Result
   is
      Text       : constant String := Focused_Text (Model);
      Cursor     : constant Natural := Files.Model.Text_Cursor_Position (Model);
      New_Text   : Unbounded_String;
      New_Cursor : Natural;
   begin
      --  No focused field: the grid owns the key, so deletion is a no-op here.
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         return Make_Result (Controller_Ignored);
      end if;

      --  Rename edits broadcast to every synchronized caret via the model, which
      --  reports whether anything changed. Exactly one variant is evaluated.
      if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         declare
            Deleted : constant Boolean :=
              Files.Model.Rename_Delete (Model, Backward => Direction = Delete_Backward, By_Word => By_Word);
         begin
            return Make_Result
              (if Deleted then Controller_Text_Updated else Controller_Ignored);
         end;
      end if;

      --  Delete at the caret; a key at the near edge of the field deletes
      --  nothing and is ignored.
      Guikit.Utf8.Editing.Delete_At
        (Text, Cursor, Backward => Direction = Delete_Backward, By_Word => By_Word,
         New_Text => New_Text, New_Cursor => New_Cursor);
      if Length (New_Text) = Text'Length then
         return Make_Result (Controller_Ignored);
      end if;
      Replace_Focused_Text (Model, To_String (New_Text));
      Files.Model.Set_Text_Cursor_Position (Model, New_Cursor);
      return Make_Result (Controller_Text_Updated);
   end Delete_Focused_Text;
