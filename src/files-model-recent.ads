--  What the interaction layer persists from a window: the items opened
--  (folded into the recent list) and the paths that moved or went away
--  (which labels, favorites and recent entries follow), plus whether the
--  recent-items view is shown. Entering that view is navigation
--  (Files.Model.Navigate_Recent).
package Files.Model.Recent is

   --  Return whether the virtual recent-items view is currently shown.
   --
   --  @param Model Model to inspect.
   --  @return True while the recent-items view is active.
   function In_Recent_View
     (Model : Window_Model)
      return Boolean;

   --  Record Path as an item that was just opened, queued for the settings layer
   --  to fold into the persisted recent list. Both files and folders are
   --  recorded; the empty path is ignored.
   --
   --  @param Model Model to update.
   --  @param Path Full path of the opened item.
   procedure Note_Recent_Open
     (Model : in out Window_Model;
      Path  : String);

   --  Return and clear the paths queued by Note_Recent_Open since the last drain.
   --  The interaction layer calls this after dispatching a user action to persist
   --  any newly opened items into the recent list.
   --
   --  @param Model Model to update.
   --  @return Opened paths in the order they were recorded.
   function Take_Recent_Opens
     (Model : in out Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Record that the item at From now lives at To (a rename, a move, or Undo
   --  or Redo of one), so the interaction layer can make labels, favorites and
   --  recent entries follow it.
   --
   --  @param Model Model to update.
   --  @param From Old full path.
   --  @param To New full path.
   procedure Note_Path_Move
     (Model : in out Window_Model;
      From  : String;
      To    : String);

   --  Record that the item at Path is gone for good (deleted, or purged from
   --  the trash), so labels and favorites naming it are forgotten. Queued
   --  with Note_Path_Move as a Removed move.
   --
   --  @param Model Model to update.
   --  @param Path Full path of the removed item.
   procedure Note_Path_Removed
     (Model : in out Window_Model;
      Path  : String);

   --  Return and clear the moves and removals queued by Note_Path_Move and
   --  Note_Path_Removed, in order.
   --
   --  @param Model Model to update.
   --  @return The queued moves; a removal is Kind Removed with an empty To.
   function Take_Path_Moves
     (Model : in out Window_Model)
      return Files.Types.Path_Move_Vectors.Vector;

end Files.Model.Recent;
