separate (Files.Model)
   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Command_Palette_Mode := Mode;
      --  The command list is mode-specific; reload it and reset the query.
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
   end Set_Command_Palette_Mode;
