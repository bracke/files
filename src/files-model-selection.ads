--  The selection state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Selection is

   --  Select a visible item by one-based visible index.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Select_Visible
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Toggle a visible item in the deterministic multi-selection set.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible item index.
   procedure Toggle_Visible_Selection
     (Model         : in out Window_Model;
      Visible_Index : Positive);

   --  Select a deterministic inclusive visible range.
   --
   --  @param Model Model to update.
   --  @param Anchor_Index One-based range anchor in the visible projection.
   --  @param Target_Index One-based range target in the visible projection.
   procedure Select_Visible_Range
     (Model        : in out Window_Model;
      Anchor_Index : Positive;
      Target_Index : Positive);

   --  Select all currently visible loaded directory items.
   --
   --  Temporary create-file items are excluded because they do not exist on
   --  disk until committed.
   --
   --  @param Model Model to update.
   procedure Select_All_Visible
     (Model : in out Window_Model);

   --  Clear the deterministic multi-selection set and primary selection.
   --
   --  @param Model Model to update.
   procedure Clear_Selection
     (Model : in out Window_Model);

   --  Invert the selection across the currently visible loaded items.
   --
   --  Every visible directory item that is currently selected becomes
   --  unselected and every visible unselected item becomes selected. The
   --  current directory and view stay intact. Temporary create-file items are
   --  excluded because they do not exist on disk until committed.
   --
   --  @param Model Model to update.
   procedure Invert_Selection
     (Model : in out Window_Model);

   --  Clear the entire selection (deselect all visible items).
   --
   --  @param Model Model to update.
   procedure Deselect_All
     (Model : in out Window_Model);

   --  Move selection in the visible projection with wraparound.
   --
   --  @param Model Model to update.
   --  @param Direction Direction requested by user input.
   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction);

   --  Select the first visible item (visible index one).
   --
   --  Clears the selection when nothing is visible. Intended for the keyboard
   --  Home shortcut while the file grid is focused.
   --
   --  @param Model Model to update.
   procedure Select_First_Visible
     (Model : in out Window_Model);

   --  Select the last visible item (the highest visible index).
   --
   --  Clears the selection when nothing is visible. Intended for the keyboard
   --  End shortcut while the file grid is focused.
   --
   --  @param Model Model to update.
   procedure Select_Last_Visible
     (Model : in out Window_Model);

   --  Move the single selection by whole pages within the visible projection.
   --
   --  A page spans Page_Rows grid rows, i.e. Page_Rows times the selection grid
   --  column stride items. Movement clamps at the first and last visible item
   --  (no wraparound). With nothing selected the first visible item is chosen.
   --  Intended for the keyboard Page Up / Page Down shortcuts while the file
   --  grid is focused.
   --
   --  @param Model Model to update.
   --  @param Page_Rows Number of grid rows spanned by one page.
   --  @param Down Move toward the last item when True, toward the first when False.
   procedure Move_Selection_By_Page
     (Model     : in out Window_Model;
      Page_Rows : Positive;
      Down      : Boolean);

   --  Set the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to update.
   --  @param Columns Number of visible item columns; values below one are ignored.
   procedure Set_Selection_Grid_Columns
     (Model   : in out Window_Model;
      Columns : Positive);

   --  Return the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to inspect.
   --  @return Number of visible item columns used as the vertical movement stride.
   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive;

   --  Return whether a visible item is selected.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return True when the visible item is selected.
   function Is_Selected
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Boolean;

   --  Return the selected visible index.
   --
   --  @param Model Model to inspect.
   --  @return One-based visible selected index, or zero when nothing is selected.
   function Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Return the number of selected items.
   --
   --  @param Model Model to inspect.
   --  @return Selected item count.
   function Selected_Count
     (Model : Window_Model)
      return Natural;

   --  Return the selected item name.
   --
   --  @param Model Model to inspect.
   --  @return Selected item name or an empty string.
   function Selected_Name
     (Model : Window_Model)
      return String;

   --  Return the selected item.
   --
   --  @param Model Model to inspect.
   --  @return Selected item, or a default empty item when no selection exists.
   function Selected_Item
     (Model : Window_Model)
      return Files.File_System.Directory_Item;

   --  Return all selected items in deterministic loaded-item order.
   --
   --  @param Model Model to inspect.
   --  @return Selected directory items, excluding transient create-file items.
   function Selected_Items
     (Model : Window_Model)
      return Files.File_System.Item_Vectors.Vector;

   --  Return whether the current selection is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the pending create-file item is selected.
   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean;

   --  Return whether any selected item is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the selection includes the pending create-file item.
   function Selection_Includes_Temporary
     (Model : Window_Model)
      return Boolean;

   --  Return the current focus target.
   --
   --  @param Model Model to inspect.
   --  @return Focus target.
   function Focus
     (Model : Window_Model)
      return Files.Types.Focus_Target;

   --  Select an item by name in the full loaded model.
   --
   --  @param Model Model to update.
   --  @param Name Loaded item name to select.
   --  @return True when a matching visible item was selected.
   function Select_By_Name
     (Model : in out Window_Model;
      Name  : String)
      return Boolean;

   --  Return whether Path is one of the currently selected directories.
   --
   --  @param Model Model to inspect.
   --  @param Path Absolute path to test against the selection.
   --  @return True when a selected item is a directory whose full path is Path.
   function Is_Selected_Directory
     (Model : Window_Model;
      Path  : String)
      return Boolean;

end Files.Model.Selection;
