separate (Files.Model)
procedure Set_Tree_Cursor
  (Model : in out Window_Model;
   Path  : String) is
begin
   Touch (Model);
   Model.Tree_Cursor_Value := To_Unbounded_String (Path);
end Set_Tree_Cursor;
