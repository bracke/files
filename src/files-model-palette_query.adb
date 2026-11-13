separate (Files.Model)
function Palette_Query (Model : Window_Model) return String is
begin
   return Guikit.Command_Palette.Query (Model.Command_Palette.View);
end Palette_Query;
