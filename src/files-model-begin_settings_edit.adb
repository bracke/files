separate (Files.Model)
   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Pane_Open := True;
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Reset_Settings_Panel (Model);
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Begin_Settings_Edit;
