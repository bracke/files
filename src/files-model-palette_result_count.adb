separate (Files.Model)
function Palette_Result_Count (Model : Window_Model) return Natural is
begin
   return Guikit.Command_Palette.Result_Count (Model.Command_Palette.View);
end Palette_Result_Count;
