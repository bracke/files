--  The right-click menu: where it opened, what it was opened on, and its
--  keyboard highlight.
package Files.Model.Context_Menu is

   --  Open the right-click context menu at the given window position.
   --
   --  @param Model Model to update.
   --  @param X Window-space X coordinate of the cursor.
   --  @param Y Window-space Y coordinate of the cursor.
   --  @param Target Whether the menu is anchored on an item, the empty grid, or
   --    the details-view column header.
   --  @param Item_Index Visible item index when the menu is anchored on a row.
   procedure Open
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0);

   --  Close the right-click context menu.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Return whether the context menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the context menu is open.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the anchor X coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor X coordinate in pixels.
   function X
     (Model : Window_Model)
      return Natural;

   --  Return the anchor Y coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor Y coordinate in pixels.
   function Y
     (Model : Window_Model)
      return Natural;

   --  Return whether the menu was opened on an item or the empty area.
   --
   --  @param Model Model to inspect.
   --  @return Whether the menu targets an item or the empty area.
   function Target_Of
     (Model : Window_Model)
      return Context_Menu_Target;

   --  Return the item index the menu was anchored to (0 when empty area).
   --
   --  @param Model Model to inspect.
   --  @return The anchored item index, or 0 when opened on the empty area.
   function Item_Index
     (Model : Window_Model)
      return Natural;

   --  Set the one-based index of the keyboard-highlighted context-menu row (0
   --  for none). The controller resolves which row is a selectable command via
   --  Files.Commands.Context_Menu_Rows_For and stores the result here.
   --
   --  @param Model Model to update.
   --  @param Row Highlighted row index, or 0 for none.
   procedure Set_Highlight
     (Model : in out Window_Model;
      Row   : Natural);

   --  The one-based index of the keyboard-highlighted context-menu row, or 0
   --  when none is highlighted (e.g. a menu opened by mouse and not yet arrowed).
   --
   --  @param Model Model to inspect.
   --  @return Highlighted row index, or 0.
   function Highlight
     (Model : Window_Model)
      return Natural;

end Files.Model.Context_Menu;
