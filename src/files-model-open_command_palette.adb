separate (Files.Model)
   procedure Open_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Command_Palette_Open := True;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette_View, Palette_Config (20, Palette_Commands));
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Model.Focus_Value := Files.Types.Focus_Command_Palette;
   end Open_Command_Palette;
