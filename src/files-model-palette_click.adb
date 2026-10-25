separate (Files.Model)
function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   Clicked : constant Boolean :=
     Guikit.Command_Palette.Click (Model.Command_Palette_View, X, Y);
begin
   if Clicked then
      Model.Revision_Value := Model.Revision_Value + 1;
   end if;
   return Clicked;
end Palette_Click;
