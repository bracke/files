separate (Files.Model)
function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   Clicked : constant Boolean :=
     Guikit.Command_Palette.Click (Model.Command_Palette.View, X, Y);
begin
   if Clicked then
      Touch (Model);
   end if;
   return Clicked;
end Palette_Click;
