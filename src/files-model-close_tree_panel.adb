separate (Files.Model)
   procedure Close_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := False;
      --  Closing the sidebar also abandons any in-flight destination picker so
      --  a later reopen starts clean.
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
   end Close_Tree_Panel;
