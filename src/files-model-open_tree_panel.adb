separate (Files.Model)
   procedure Open_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := True;
   end Open_Tree_Panel;
