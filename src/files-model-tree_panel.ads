--  The tree panel state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Tree_Panel is

   --  Toggle the folder-tree sidebar visibility.
   --
   --  @param Model Model to update.
   procedure Toggle_Tree_Panel
     (Model : in out Window_Model);

   --  Open the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Open_Tree_Panel
     (Model : in out Window_Model);

   --  Close the folder-tree sidebar.
   --
   --  @param Model Model to update.
   procedure Close_Tree_Panel
     (Model : in out Window_Model);

   --  Return whether the folder-tree sidebar is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the tree sidebar is open.
   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return whether the folder tree has been seeded with root nodes.
   --
   --  @param Model Model to inspect.
   --  @return True once the tree holds its root nodes.
   function Tree_Is_Seeded
     (Model : Window_Model)
      return Boolean;

   --  Seed the folder tree with root nodes.
   --
   --  @param Model Model to update.
   --  @param Roots Root locations shown at the top of the tree.
   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Return the number of nodes currently held by the folder tree.
   --
   --  @param Model Model to inspect.
   --  @return Total tree node count.
   function Tree_Node_Count
     (Model : Window_Model)
      return Natural;

   --  Return a tree node's absolute directory path.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return Node path, or an empty string when Index is out of range.
   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return whether a tree node's children have been loaded.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return True when the node's children are attached.
   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Return whether a tree node is currently expanded.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based node index.
   --  @return True when the node shows its children.
   function Tree_Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

   --  Attach a tree node's child subdirectories and mark it loaded.
   --
   --  @param Model Model to update.
   --  @param Index One-based parent node index.
   --  @param Children Child subdirectories in display order.
   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector);

   --  Set a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   --  @param Expanded New expanded state.
   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean);

   --  Flip a tree node's expanded flag.
   --
   --  @param Model Model to update.
   --  @param Index One-based node index.
   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive);

   --  Return the flattened, currently visible folder-tree rows.
   --
   --  @param Model Model to inspect.
   --  @return Visible tree rows in top-to-bottom display order.
   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector;

   --  Begin the destination-picker sub-mode: record the copy/move intent, the
   --  captured source paths, and the initial highlighted target directory.
   --
   --  @param Model Model to update.
   --  @param Mode Copy or move intent (Pick_None clears the picker).
   --  @param Sources Full source paths to copy or move.
   --  @param Initial_Target Directory highlighted as the initial destination.
   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String);

   --  Set the highlighted destination directory for the active picker.
   --
   --  @param Model Model to update.
   --  @param Target Directory to highlight as the destination.
   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String);

   --  Clear the destination-picker sub-mode and its captured sources.
   --
   --  @param Model Model to update.
   procedure Clear_Tree_Pick
     (Model : in out Window_Model);

   --  Return the active destination-picker mode.
   --
   --  @param Model Model to inspect.
   --  @return Pick_None when no destination picker is active.
   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode;

   --  Return whether a destination picker is active.
   --
   --  @param Model Model to inspect.
   --  @return True when a Copy to.../Move to... picker is running.
   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the captured destination-picker source paths.
   --
   --  @param Model Model to inspect.
   --  @return Source paths to copy or move when the picker confirms.
   function Tree_Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return the highlighted destination directory.
   --
   --  @param Model Model to inspect.
   --  @return Currently highlighted destination path, or an empty string.
   function Tree_Pick_Target
     (Model : Window_Model)
      return String;

end Files.Model.Tree_Panel;
