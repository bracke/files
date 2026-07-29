separate (Files.Model)
   procedure Toggle_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Command_Palette_Open then
         Close_Command_Palette (Model);
      else
         Open_Command_Palette (Model);
      end if;
   end Toggle_Command_Palette;
