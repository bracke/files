separate (Files.Model)
   procedure Focus_Filter_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Filter_Input;
      Model.Filter_Cursor := Length (Model.Filter_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Filter_Input;
