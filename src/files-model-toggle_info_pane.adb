separate (Files.Model)
   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Info_Pane_Open := not Model.Info_Pane_Open;
      Model.Info_Pane_Scroll := 0;
   end Toggle_Info_Pane;
