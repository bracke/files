with Guikit.Command_Palette;

with Files.Model;

--  The palette command list for the current mode. Guikit.Command_Palette owns
--  the query, selection, scroll, filtering and rendering; this package only
--  supplies the full (unfiltered) command list and lets the controller map a
--  chosen command's Id back to an action.
package Files.Command_Palette is

   --  All commands offered by the palette in the current mode, unfiltered:
   --  every visible registered command (Commands mode), or every installed
   --  application (Open-With mode). Each command's Id is the Files.Commands
   --  enumeration position (Commands mode) or the one-based index into
   --  Files.Applications.Available_Applications (Open-With mode).
   --
   --  @param Model Current model, for the mode and command enablement.
   --  @return The commands to hand to Guikit.Command_Palette.
   function Commands
     (Model : Files.Model.Window_Model)
      return Guikit.Command_Palette.Command_Vectors.Vector;

end Files.Command_Palette;
