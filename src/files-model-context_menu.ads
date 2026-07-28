--  The context menu state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Context_Menu is

   --  Open the right-click context menu at the given window position.
   --
   --  @param Model Model to update.
   --  @param X Window-space X coordinate of the cursor.
   --  @param Y Window-space Y coordinate of the cursor.
   --  @param Target Whether the menu is anchored on an item, the empty grid, or
   --    the details-view column header.
   --  @param Item_Index Visible item index when the menu is anchored on a row.
   procedure Open_Context_Menu
     (Model      : in out Window_Model;
      X          : Natural;
      Y          : Natural;
      Target     : Context_Menu_Target;
      Item_Index : Natural := 0);

   --  Close the right-click context menu.
   --
   --  @param Model Model to update.
   procedure Close_Context_Menu
     (Model : in out Window_Model);

   --  Return whether the context menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the context menu is open.
   function Context_Menu_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the anchor X coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor X coordinate in pixels.
   function Context_Menu_X
     (Model : Window_Model)
      return Natural;

   --  Return the anchor Y coordinate.
   --
   --  @param Model Model to inspect.
   --  @return The context menu's anchor Y coordinate in pixels.
   function Context_Menu_Y
     (Model : Window_Model)
      return Natural;

   --  Return whether the menu was opened on an item or the empty area.
   --
   --  @param Model Model to inspect.
   --  @return Whether the menu targets an item or the empty area.
   function Context_Menu_Target_Of
     (Model : Window_Model)
      return Context_Menu_Target;

   --  Return the item index the menu was anchored to (0 when empty area).
   --
   --  @param Model Model to inspect.
   --  @return The anchored item index, or 0 when opened on the empty area.
   function Context_Menu_Item_Index
     (Model : Window_Model)
      return Natural;

end Files.Model.Context_Menu;
