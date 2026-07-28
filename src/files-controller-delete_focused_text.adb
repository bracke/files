separate (Files.Controller)
   function Delete_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Direction : Delete_Direction;
      By_Word   : Boolean)
      return Controller_Result
   is
      Text     : constant String := Focused_Text (Model);
      Cursor   : constant Natural := Files.Model.Text_Cursor_Position (Model);
      Boundary : Natural;
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
              (case Direction is
                  when Delete_Backward =>
                    (if By_Word then Files.Model.Rename_Delete_Word_Backward (Model)
                     else Files.Model.Rename_Delete_Backward (Model)),
                  when Delete_Forward =>
                    (if By_Word then Files.Model.Rename_Delete_Word_Forward (Model)
                     else Files.Model.Rename_Delete_Forward (Model)));
         begin
            return Make_Result
              (if Deleted then Controller_Text_Updated else Controller_Ignored);
         end;
      end if;

      --  Nothing to delete past the near edge of the field.
      if (Direction = Delete_Backward and then Cursor = 0)
        or else (Direction = Delete_Forward and then Cursor >= Text'Length)
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Direction is
         when Delete_Backward =>
            Boundary :=
              (if By_Word then Previous_Word_Boundary (Text, Cursor)
               else Previous_Text_Boundary (Text, Cursor));
            Replace_Focused_Text (Model, Files.UTF8.Remove_Range (Text, Boundary, Cursor));
            Files.Model.Set_Text_Cursor_Position (Model, Boundary);
         when Delete_Forward =>
            Boundary :=
              (if By_Word then Next_Word_Boundary (Text, Cursor)
               else Next_Text_Boundary (Text, Cursor));
            Replace_Focused_Text (Model, Files.UTF8.Remove_Range (Text, Cursor, Boundary));
            Files.Model.Set_Text_Cursor_Position (Model, Cursor);
      end case;
      return Make_Result (Controller_Text_Updated);
   end Delete_Focused_Text;
