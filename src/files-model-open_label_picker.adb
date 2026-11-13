separate (Files.Model)
procedure Open_Label_Picker
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Claim_Overlay_Input (Model);
   --  Start the keyboard highlight on the clear swatch; the item's current
   --  label lives in the settings, which this model operation does not see.
   Model.Label_Picker := (Active => True, Swatch => Files.Types.Clear_Swatch);
end Open_Label_Picker;
