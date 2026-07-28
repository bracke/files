package body Files.Model.Label_Picker is

   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Open_With_Targets_Value := Targets;
   end Set_Open_With_Targets;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Open_With_Targets_Value;
   end Open_With_Targets;

   procedure Open_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := True;
   end Open_Label_Picker;

   procedure Close_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := False;
   end Close_Label_Picker;

   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Label_Picker_Active;
   end Label_Picker_Is_Open;

end Files.Model.Label_Picker;
