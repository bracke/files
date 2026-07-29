separate (Files.Model)
   procedure Palette_Select_First (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Command_Palette.Select_First (Model.Command_Palette_View);
   end Palette_Select_First;
