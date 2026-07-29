separate (Files.Model)
   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      return Guikit.Command_Palette.Click (Model.Command_Palette_View, X, Y);
   end Palette_Click;
