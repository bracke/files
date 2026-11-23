private with Guikit.Command_Palette;

private with Files.Desktop_Applications;
with Files.Model;

--  The palette's command list, its rows in the current language. Guikit.
--  Command_Palette owns the query, selection, scroll, filtering and
--  rendering, and Files.Model.Command_Palette the palette's state, which
--  this package hands what it lists (Ensure_Listed); the model never calls
--  back here. The localizing stays here, outside the model.
package Files.Overlays.Command_Palette is

   --  List the palette's commands for its mode and the model as it is, when
   --  what it lists is not (Files.Model.Command_Palette.Is_Listed): before
   --  the palette is drawn, and before a key, the wheel or Enter acts on its
   --  rows, which may come ahead of the first frame after it opened.
   --
   --  @param Model Model whose palette is listed.
   procedure Ensure_Listed (Model : in out Files.Model.Window_Model);

private

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

end Files.Overlays.Command_Palette;
