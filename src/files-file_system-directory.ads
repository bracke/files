--  The directory operations of Files.File_System, extracted into
--  a concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.File_System.Directory is

   --  Load the direct children of a directory.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

   --  Stat a single path and build its directory item, classifying kind,
   --  filetype, icon, and metadata the same way directory loading does. Used to
   --  materialize a synthetic listing (such as the recent-items view) from a set
   --  of stored paths.
   --
   --  @param Full_Path Absolute or relative path to describe.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded item, or a failure result when the path is missing or
   --  cannot be described.
   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result;

   --  Compute the "extra info" token for an item: a folder's child count, a
   --  document's page/entry/line count, or a symlink's target. This opens the
   --  folder or reads the file, so it is computed lazily for the selected item
   --  (via the window model) rather than for every item on load.
   --
   --  @param Path Full path of the item.
   --  @param Kind Item kind.
   --  @param Filetype Detected filetype (MIME-style) of the item.
   --  @return An opaque token consumed by the renderer, or "" when there is no
   --    extra info for the item.
   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String;

   --  Sort Items in place into the display order for the given sort field and
   --  direction. Shared by directory loading and by the window model so that
   --  keyboard navigation follows exactly the order shown on screen, in either
   --  sort direction.
   --
   --  @param Items Item vector reordered in place.
   --  @param Field Sort field to order by.
   --  @param Ascending Ascending order when True, descending when False.
   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean);

   --  Compute a shallow signature for polling-based directory change detection.
   --
   --  @param Path Directory to inspect.
   --  @return Directory existence, item count, and latest modification time.
   function Directory_State
     (Path : String)
      return Directory_Signature;

   --  Compare two polling signatures for a directory.
   --
   --  @param Before_State Previously captured directory state.
   --  @param Path Directory to inspect again.
   --  @return Change result with the new state.
   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result;

   --  Sum the sizes of every descendant regular file under a directory.
   --
   --  The walk skips symbolic links (it never descends through a symlinked
   --  directory, which guards against link cycles) and stops early against two
   --  defensive caps: at most Max_Entries visited entries and Max_Depth levels
   --  of nesting. When a cap trips the result's Capped flag is set and the
   --  totals become a lower bound. Unreadable subdirectories are skipped rather
   --  than aborting the whole walk.
   --
   --  @param Path Directory whose contents are summed.
   --  @param Max_Entries Maximum number of entries to visit before capping.
   --  @param Max_Depth Maximum directory nesting depth to descend.
   --  @return Recursive size totals; Available is False when Path is unusable.
   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result;

   --  Build an item value for tests and pure model setup.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier.
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item;

   --  Build an item value using settings-driven filetype and icon classification.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item;

end Files.File_System.Directory;
