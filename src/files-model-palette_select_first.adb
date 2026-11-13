separate (Files.Model)
procedure Palette_Select_First (Model : in out Window_Model) is
begin
   Touch (Model);
   Guikit.Command_Palette.Select_First (Model.Command_Palette.View);
end Palette_Select_First;
