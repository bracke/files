separate (Files.Model)
   procedure Palette_Set_Query (Model : in out Window_Model; Text : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Command_Palette.Set_Query (Model.Command_Palette_View, Text);
   end Palette_Set_Query;
