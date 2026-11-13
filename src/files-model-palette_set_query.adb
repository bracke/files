separate (Files.Model)
procedure Palette_Set_Query (Model : in out Window_Model; Text : String) is
begin
   Touch (Model);
   Guikit.Command_Palette.Set_Query (Model.Command_Palette.View, Text);
end Palette_Set_Query;
