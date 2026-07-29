separate (Files.Model)
   procedure Reset_Type_Ahead
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Reset_Type_Ahead;
