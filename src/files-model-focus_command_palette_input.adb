separate (Files.Model)
   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Command_Palette_Open then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Command_Palette;
      end if;
   end Focus_Command_Palette_Input;
