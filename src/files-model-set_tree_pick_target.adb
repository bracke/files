separate (Files.Model)
   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Target_Value := To_Unbounded_String (Target);
   end Set_Tree_Pick_Target;
