separate (Files.Model)
procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
begin
   Touch (Model);
   Guikit.Command_Palette.Move_Selection (Model.Command_Palette_View, Delta_Rows);
end Palette_Move_Selection;
