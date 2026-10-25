separate (Files.Model)
procedure Give_Tree_Keyboard
  (Model : in out Window_Model)
is
   Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
     Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
begin
   if not Model.Tree_Panel_Open
     or else Model.Tree_Pick_Mode_Value /= Pick_None
     or else Rows.Is_Empty
   then
      return;
   end if;

   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Tree_Keyboard_Value := True;
   Model.Tree_Cursor_Value := Rows.First_Element.Path;
   for Row of Rows loop
      if Row.Path = Model.Current_Path_Value then
         Model.Tree_Cursor_Value := Row.Path;
         exit;
      end if;
   end loop;
end Give_Tree_Keyboard;
