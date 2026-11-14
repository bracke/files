with Files.Model.Command_Palette;

separate (Files.Operations)
procedure Begin_Open_With (Model : in out Files.Model.Window_Model) is
begin
   --  The installed applications are read once, as the picker opens.
   Files.Model.Command_Palette.Open_With
     (Model, Files.Model.Selection.Selected_Paths (Model), Files.Desktop_Applications.Available_Applications);
   Files.Model.Set_Error (Model, "");
end Begin_Open_With;
