with Files.UI_Types;

--  Which commands the right-click context menus show, in order, with their
--  separators: the item menu, the empty-area menu and the column-header
--  menu. Shared by the renderer (layout and hit test), the controller
--  (keyboard navigation and activation) and command status.
package Files.Commands.Context_Menus is

   --  The rows the right-click context menu shows for a target, in order --
   --  command rows interleaved with separator dividers. Shared by the renderer
   --  (which lays them out and hit-tests them) and the controller (which
   --  navigates and activates them by keyboard) so both agree on the set.
   --  The item menu carries 19 commands split into 6 groups by 5 separators
   --  (24 rows); the bound keeps headroom so the fixed arrays never overflow.
   Max_Context_Menu_Rows : constant := 26;

   type Context_Menu_Row_Kind is (Menu_Command, Menu_Separator);

   type Context_Menu_Row is record
      Kind    : Context_Menu_Row_Kind := Menu_Separator;
      Command : Command_Id := No_Command;
   end record;

   type Context_Menu_Row_Array is
     array (1 .. Max_Context_Menu_Rows) of Context_Menu_Row;

   type Context_Menu_Rows is record
      Rows  : Context_Menu_Row_Array;
      Count : Natural := 0;
   end record;

   --  Return the ordered rows for a context-menu target.
   --
   --  @param Target Which context menu (item / empty area / column header).
   --  @return The rows for that target (Count is zero for Context_Menu_None).
   function Context_Menu_Rows_For
     (Target : Files.UI_Types.Context_Menu_Target)
      return Context_Menu_Rows;

end Files.Commands.Context_Menus;
