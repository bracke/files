separate (Files.Model)
   procedure Toggle_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := not Model.Tree_Panel_Open;
   end Toggle_Tree_Panel;
