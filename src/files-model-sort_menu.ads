--  The sort menu over the bottom bar and its keyboard highlight.
package Files.Model.Sort_Menu is

   --  Toggle the bottom-bar sort menu visibility.
   --
   --  @param Model Model to update.
   procedure Toggle
     (Model : in out Window_Model);

   --  Close the bottom-bar sort menu.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Return whether the bottom-bar sort menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the sort menu is open.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Move the keyboard highlight across the sort menu's five rows (1 .. 5,
   --  mirroring the sort fields), clamped to that range.
   --
   --  @param Model Model to update.
   --  @param Delta_Value Signed number of rows to move.
   procedure Move_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer);

   --  The one-based index of the highlighted sort-menu row (0 when none), for
   --  rendering.
   --
   --  @param Model Model to inspect.
   --  @return Highlighted row index, 0 or 1 .. 5.
   function Highlight
     (Model : Window_Model)
      return Natural;

   --  The sort field the highlighted sort-menu row selects, for applying a
   --  keyboard confirmation.
   --
   --  @param Model Model to inspect.
   --  @return Sort field under the highlight.
   function Highlight_Field
     (Model : Window_Model)
      return Files.Types.Sort_Field;

end Files.Model.Sort_Menu;
