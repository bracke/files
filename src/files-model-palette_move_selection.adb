separate (Files.Model)
   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Guikit.Command_Palette.Move_Selection (Model.Command_Palette_View, Delta_Rows);
   end Palette_Move_Selection;
