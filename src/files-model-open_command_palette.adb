with Files.Command_Palette;
with Guikit.Layout;
separate (Files.Model)
procedure Open_Command_Palette
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Command_Palette_Open := True;
   Model.Command_Palette_Mode := Palette_Commands;
   Model.Open_With_Targets_Value.Clear;
   Model.Open_With_Applications_Value.Clear;
   Claim_Overlay_Input (Model);
   --  At the reference line height; Visit_Command_Palette sets the window's
   --  real one.
   Guikit.Command_Palette.Set_Configuration
     (Model.Command_Palette_View, Palette_Config (Guikit.Layout.Reference_Line_Height));
   Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   Guikit.Command_Palette.Set_Commands
     (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
   Model.Focus_Value := Files.Types.Focus_Command_Palette;
end Open_Command_Palette;
