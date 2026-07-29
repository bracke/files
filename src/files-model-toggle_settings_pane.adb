separate (Files.Model)
   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Settings_Pane_Open := not Model.Settings_Pane_Open;
      if Model.Settings_Pane_Open then
         Clear_Edit_State (Model);
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
         Reset_Settings_Panel (Model);
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      elsif Model.Focus_Value = Files.Types.Focus_Settings_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Toggle_Settings_Pane;
