separate (Files.Model)
   procedure Palette_Page (Model : in out Window_Model; Down : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Command_Palette.Page (Model.Command_Palette_View, Down);
   end Palette_Page;
