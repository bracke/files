--  The view sort state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.View_Sort is

   --  Return the active view mode.
   --
   --  @param Model Model to inspect.
   --  @return Active view mode.
   function View_Mode_Of
     (Model : Window_Model)
      return Files.Types.View_Mode;

   --  Set the active view mode.
   --
   --  @param Model Model to update.
   --  @param Mode New view mode.
   procedure Set_View_Mode
     (Model : in out Window_Model;
      Mode  : Files.Types.View_Mode);

   --  Return the active item sort field.
   --
   --  @param Model Model to inspect.
   --  @return Active sort field.
   function Sort_Field_Of
     (Model : Window_Model)
      return Sort_Field;

   --  Return whether item sorting is ascending.
   --
   --  @param Model Model to inspect.
   --  @return True when sorting ascends by the active field.
   function Sort_Is_Ascending
     (Model : Window_Model)
      return Boolean;

   --  Select or toggle the active item sort field.
   --
   --  Selecting the current field toggles sort direction. Selecting a different
   --  field makes that field ascending.
   --
   --  @param Model Model to update.
   --  @param Field Sort field to select.
   procedure Select_Sort_Field
     (Model : in out Window_Model;
      Field : Sort_Field);

   --  Set the sort field and direction to absolute values and re-sort. Unlike
   --  Select_Sort_Field (which toggles direction when re-selecting the current
   --  field), this applies a known target state, for use when applying saved or
   --  persisted settings.
   --
   --  @param Model Model to update.
   --  @param Field Sort field to sort by.
   --  @param Ascending True to sort ascending, False for descending.
   procedure Apply_Sort
     (Model     : in out Window_Model;
      Field     : Sort_Field;
      Ascending : Boolean);

   --  Toggle the bottom-bar sort menu visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Sort_Menu
     (Model : in out Window_Model);

   --  Close the bottom-bar sort menu.
   --
   --  @param Model Model to update.
   procedure Close_Sort_Menu
     (Model : in out Window_Model);

   --  Return whether the bottom-bar sort menu is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the sort menu is open.
   function Sort_Menu_Is_Open
     (Model : Window_Model)
      return Boolean;

end Files.Model.View_Sort;
