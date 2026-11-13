separate (Files.Model)
procedure Palette_Select_Last (Model : in out Window_Model) is
begin
   Touch (Model);
   Guikit.Command_Palette.Select_Last (Model.Command_Palette.View);
end Palette_Select_Last;
