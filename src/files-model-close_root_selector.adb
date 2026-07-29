separate (Files.Model)
   procedure Close_Root_Selector
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Clear_Root_Selector_State (Model);
   end Close_Root_Selector;
