separate (Files.Model)
   procedure Close_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := False;
   end Close_Label_Picker;
