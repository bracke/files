with Guikit.Command_Palette;
with Files.Desktop_Applications;
with Files.Model;

--  What the suite reaches of Files.Overlays.Command_Palette that is not part
--  of its interface.
package Files.Overlays.Command_Palette.Testing is

   --  All commands offered by the palette in a mode, unfiltered.
   --
   --  @param Model Current model, for command enablement.
   --  @param Mode The palette's mode.
   --  @param Applications The applications the Open-With picker lists.
   --  @return The commands to hand to Guikit.Command_Palette.
   function Commands
     (Model        : Files.Model.Window_Model;
      Mode         : Files.Model.Palette_Mode;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector)
      return Guikit.Command_Palette.Command_Vectors.Vector;

end Files.Overlays.Command_Palette.Testing;
