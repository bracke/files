separate (Files.Model)
   procedure Deselect_All
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Clear_Selection (Model);
   end Deselect_All;
