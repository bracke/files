separate (Files.Model)
   procedure Open_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := True;
   end Open_Label_Picker;
