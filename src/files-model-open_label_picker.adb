separate (Files.Model)
--  Swatch 8 is the clear/None swatch (Files.Types.Label_For_Swatch).
procedure Open_Label_Picker
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Claim_Overlay_Input (Model);
   Model.Label_Picker_Active := True;
   --  Start the keyboard highlight on the clear swatch; the item's current
   --  label lives in the settings, which this model operation does not see.
   Model.Label_Picker_Swatch_Value := 8;
end Open_Label_Picker;
