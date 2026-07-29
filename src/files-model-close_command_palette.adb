separate (Files.Model)
   procedure Close_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Close_Command_Palette;
