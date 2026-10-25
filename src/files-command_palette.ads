with Guikit.Command_Palette;

with Files.Commands;
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
   --  Files.Model.Open_With_Applications (Open-With mode).
   --
   --  @param Model Current model, for the mode and command enablement.
   --  @return The commands to hand to Guikit.Command_Palette.
   function Commands
     (Model : Files.Model.Window_Model)
      return Guikit.Command_Palette.Command_Vectors.Vector;

   --  The command of the palette's highlighted row: the inverse of the Id
   --  Commands gives each row in Commands mode. No_Command in Open-With mode,
   --  with nothing highlighted, or for an Id outside the enumeration (a stale
   --  or malformed palette model).
   --
   --  @param Model Current model, for the mode and the highlighted row.
   --  @return The highlighted command, or No_Command.
   function Selected_Command
     (Model : Files.Model.Window_Model)
      return Files.Commands.Command_Id;

end Files.Command_Palette;
