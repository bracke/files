with Guikit.Command_Palette;

with Files.Desktop_Applications;
with Files.Model;

--  The palette's command list, its rows in the current language. Guikit.
--  Command_Palette owns the query, selection, scroll, filtering and
--  rendering, and Files.Model.Command_Palette the palette's state, which
--  hands this package what it lists: it reads nothing of the palette itself,
--  so the two do not call each other. The localizing stays here, outside
--  the model.
package Files.Command_Palette is

   --  All commands offered by the palette in a mode, unfiltered: every
   --  visible registered command (Commands mode), or every application listed
   --  (Open-With mode). Each command's Id is the Files.Commands enumeration
   --  position (Commands mode) or the one-based index into Applications
   --  (Open-With mode).
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

end Files.Command_Palette;
