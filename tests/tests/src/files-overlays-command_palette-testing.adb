package body Files.Overlays.Command_Palette.Testing is

   function Commands
     (Model        : Files.Model.Window_Model;
      Mode         : Files.Model.Palette_Mode;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector)
      return Guikit.Command_Palette.Command_Vectors.Vector renames Files.Overlays.Command_Palette.Commands;

end Files.Overlays.Command_Palette.Testing;
