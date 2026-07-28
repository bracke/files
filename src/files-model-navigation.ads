--  The navigation state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Navigation is

   --  Return the model current path.
   --
   --  @param Model Model to inspect.
   --  @return Current directory path.
   function Current_Path
     (Model : Window_Model)
      return String;

   --  Return the last stored directory polling signature.
   --
   --  @param Model Model to inspect.
   --  @return Stored directory signature for the current path.
   function Directory_Signature_Of
     (Model : Window_Model)
      return Files.File_System.Directory_Signature;

   --  Replace the stored directory polling signature.
   --
   --  @param Model Model to update.
   --  @param Signature Signature captured after loading or polling a directory.
   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature);

   --  Return the model home path.
   --
   --  @param Model Model to inspect.
   --  @return Home directory path.
   function Home_Path
     (Model : Window_Model)
      return String;

   --  Return the number of loaded directory items.
   --
   --  @param Model Model to inspect.
   --  @return Loaded item count.
   function Item_Count
     (Model : Window_Model)
      return Natural;

   --  Return the number of visible items after filtering.
   --
   --  @param Model Model to inspect.
   --  @return Visible item count.
   function Visible_Count
     (Model : Window_Model)
      return Natural;

   --  Return the number of loaded hidden items.
   --
   --  Hidden items are loaded directory items whose simple name begins with a
   --  dot. This lets the bottom bar report how many dot-files are present.
   --
   --  @param Model Model to inspect.
   --  @return Count of loaded items whose simple name begins with '.'.
   function Hidden_Item_Count
     (Model : Window_Model)
      return Natural;

   --  Return a visible item by one-based visible index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible item index.
   --  @return Directory item at Visible_Index.
   function Visible_Item
     (Model         : Window_Model;
      Visible_Index : Positive)
      return Files.File_System.Directory_Item;

   --  Return every visible row in display order in a single pass.
   --
   --  Equivalent to reading Visible_Item and Is_Selected over
   --  1 .. Visible_Count, but resolves the visible sequence and selection
   --  membership once (O(N)) instead of rescanning the item list per row.
   --  The sequence is the filtered items in order followed by the temporary
   --  placeholder item when one is active.
   --
   --  @param Model Model to inspect.
   --  @return Visible items in display order, each flagged selected or not.
   function Visible_Rows
     (Model : Window_Model)
      return Visible_Row_Vectors.Vector;

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

   --  Return whether back navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the back-history stack is not empty.
   function Can_Go_Back
     (Model : Window_Model)
      return Boolean;

   --  Return whether forward navigation is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the forward-history stack is not empty.
   function Can_Go_Forward
     (Model : Window_Model)
      return Boolean;

end Files.Model.Navigation;
