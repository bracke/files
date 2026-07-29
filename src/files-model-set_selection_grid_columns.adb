separate (Files.Model)
   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Selection_Columns := Columns;
   end Set_Selection_Grid_Columns;
