separate (Files.Model)
procedure Palette_Page (Model : in out Window_Model; Down : Boolean) is
begin
   Touch (Model);
   Guikit.Command_Palette.Page (Model.Command_Palette.View, Down);
end Palette_Page;
