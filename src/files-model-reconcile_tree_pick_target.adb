separate (Files.Model)
procedure Reconcile_Tree_Pick_Target
  (Model          : in out Window_Model;
   Fallback_Index : Positive)
is
   Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
     Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
   Target : constant String := To_String (Model.Tree_Pick.Target);
   Fallback : constant String :=
     Files.Folder_Tree.Node_Path (Model.Folder_Tree_Value, Fallback_Index);
   Target_Visible   : Boolean := False;
   Fallback_Visible : Boolean := False;
begin
   if Model.Tree_Pick.Mode = Pick_None or else Target = "" then
      return;
   end if;

   for Row of Rows loop
      Target_Visible :=
        Target_Visible or else To_String (Row.Path) = Target;
      Fallback_Visible :=
        Fallback_Visible or else To_String (Row.Path) = Fallback;
   end loop;

   if Target_Visible then
      return;
   elsif Fallback_Visible then
      Model.Tree_Pick.Target := To_Unbounded_String (Fallback);
   elsif not Rows.Is_Empty then
      Model.Tree_Pick.Target := Rows.First_Element.Path;
   else
      Model.Tree_Pick.Target := Null_Unbounded_String;
   end if;
end Reconcile_Tree_Pick_Target;
