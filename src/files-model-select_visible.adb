separate (Files.Model)
   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Select_Visible_Internal (Model, Visible_Index);
   end Select_Visible;
