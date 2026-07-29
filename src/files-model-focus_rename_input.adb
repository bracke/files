separate (Files.Model)
   procedure Focus_Rename_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Rename_Input;
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      end if;
   end Focus_Rename_Input;
