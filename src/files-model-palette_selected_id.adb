separate (Files.Model)
function Palette_Selected_Id (Model : Window_Model) return Natural is
begin
   return Guikit.Command_Palette.Selected_Id (Model.Command_Palette.View);
end Palette_Selected_Id;
