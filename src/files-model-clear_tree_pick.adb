separate (Files.Model)
   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
   end Clear_Tree_Pick;
