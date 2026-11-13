--  The folder-tree side panel: its rows, scroll, keyboard cursor, and the
--  Copy to.../Move to... destination picker drawn over it.
package Files.Model.Tree_Panel is

   --  Open the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Open
     (Model : in out Window_Model);

   --  Close the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Return whether the folder-tree sidebar is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the tree sidebar is open.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Scroll the visible folder-tree rows. Positive values move down and
   --  negative values move up.
   --
   --  @param Model Model to update.
   --  @param Rows Signed number of rows to scroll.
   procedure Scroll
     (Model : in out Window_Model;
      Rows  : Integer);

   --  Zero-based index of the first requested folder-tree row.
   --
   --  @param Model Model to inspect.
   --  @return Current zero-based folder-tree row offset.
   function Scroll_Rows
     (Model : Window_Model)
      return Natural;

   --  Set the zero-based first requested tree row, clamped to the available
   --  rows. Used by direct scrollbar manipulation.
   --
   --  @param Model Model to update.
   --  @param Rows Requested zero-based folder-tree row offset.
   procedure Set_Scroll_Rows
     (Model : in out Window_Model;
      Rows  : Natural);

   --  Adjust the tree offset only when a visible row lies outside the current
   --  viewport. Page_Rows is the number of rows supplied by the live layout.
   --
   --  @param Model Model to update.
   --  @param Visible_Row One-based visible row that must remain in view.
   --  @param Page_Rows Number of visible rows in the current viewport.
   procedure Ensure_Row_Visible
     (Model       : in out Window_Model;
      Visible_Row : Positive;
      Page_Rows   : Natural);

   --  Return whether the folder tree has been seeded with root nodes.
   --
   --  @param Model Model to inspect.
   --  @return True once the tree holds its root nodes.
   function Is_Seeded
     (Model : Window_Model)
      return Boolean;

   --  Whether the folder tree's roots are Roots, in order.
   --
   --  @param Model Model to inspect.
   --  @param Roots Root locations to compare with.
   --  @return True when the tree was seeded with exactly these.
   function Roots_Match
     (Model : Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
      return Boolean;

   --  Seed the folder tree with root nodes.
   --
   --  @param Model Model to update.
   --  @param Roots Root locations shown at the top of the tree.
   procedure Seed
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Return the number of nodes currently held by the folder tree.
   --
   --  @param Model Model to inspect.
   --  @return Total tree node count.
   function Node_Count
     (Model : Window_Model)
      return Natural;

   --  Return a tree node's absolute directory path.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return Node path, or an empty string when Index is out of range.
   function Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return whether a tree node is currently expanded.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return True when the node shows its children.
   function Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Attach a tree node's child subdirectories in place of those it had
   --  (Files.Folder_Tree.Replace_Children): children still there keep their
   --  nodes and expanded subtrees, and the tree pick target follows them.
   --
   --  @param Model Model to update.
   --  @param Index One-based parent node index.
   --  @param Children Child subdirectories in display order.
   procedure Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Set a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   --  @param Expanded New expanded state.
   procedure Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean);

   --  Flip a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   procedure Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive);

   --  Return the flattened, currently visible folder-tree rows.
   --
   --  @param Model Model to inspect.
   --  @return Visible tree rows in top-to-bottom display order.
   function Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector;

   --  Hand the keyboard to the folder tree side panel: arrows then move a
   --  highlighted row instead of the grid selection. The highlight starts on
   --  the current folder when the tree shows it, else on the first row.
   --
   --  @param Model Model to update.
   procedure Give_Keyboard
     (Model : in out Window_Model);

   --  Give the keyboard back to the grid.
   --
   --  @param Model Model to update.
   procedure Take_Keyboard
     (Model : in out Window_Model);

   --  Return whether the folder tree has the keyboard: it was given it, the
   --  panel is open, no destination picker runs and no text field is focused.
   --
   --  @param Model Model to inspect.
   --  @return True when arrows and Enter act on the tree.
   function Has_Keyboard
     (Model : Window_Model)
      return Boolean;

   --  Return the tree row highlighted for the keyboard.
   --
   --  @param Model Model to inspect.
   --  @return Path of the highlighted folder, or an empty string.
   function Cursor
     (Model : Window_Model)
      return String;

   --  Move the keyboard highlight to a folder of the tree.
   --
   --  @param Model Model to update.
   --  @param Path Folder to highlight.
   procedure Set_Cursor
     (Model : in out Window_Model;
      Path  : String);

   --  Begin the destination-picker sub-mode: record the copy/move intent, the
   --  captured source paths, and the initial highlighted target directory.
   --
   --  @param Model Model to update.
   --  @param Mode Copy or move intent (Pick_None clears the picker).
   --  @param Sources Full source paths to copy or move.
   --  @param Initial_Target Directory highlighted as the initial destination.
   procedure Begin_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String);

   --  Set the highlighted destination directory for the active picker.
   --
   --  @param Model Model to update.
   --  @param Target Directory to highlight as the destination.
   procedure Set_Pick_Target
     (Model  : in out Window_Model;
      Target : String);

   --  Finish the destination picker: close the folder tree when the picker
   --  opened it, or else leave the tree as the user had it.
   --
   --  @param Model Model to update.
   procedure End_Pick
     (Model : in out Window_Model);

   --  Return the active destination-picker mode.
   --
   --  @param Model Model to inspect.
   --  @return Pick_None when no destination picker is active.
   function Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode;

   --  Return whether a destination picker is active.
   --
   --  @param Model Model to inspect.
   --  @return True when a Copy to.../Move to... picker is running.
   function Pick_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the captured destination-picker source paths.
   --
   --  @param Model Model to inspect.
   --  @return Source paths to copy or move when the picker confirms.
   function Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return the highlighted destination directory.
   --
   --  @param Model Model to inspect.
   --  @return Currently highlighted destination path, or an empty string.
   function Pick_Target
     (Model : Window_Model)
      return String;

end Files.Model.Tree_Panel;
