--  The root selector state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Root_Selector is

   --  Open the root selector with available root paths.
   --
   --  @param Model Model to update.
   --  @param Roots Root paths to expose.
   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector);

   --  Open the root selector with root metadata entries.
   --
   --  @param Model Model to update.
   --  @param Roots Root entries to expose.
   procedure Open_Root_Selector
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector);

   --  Close the root selector.
   --
   --  @param Model Model to update.
   procedure Close_Root_Selector
     (Model : in out Window_Model);

   --  Return whether the root selector is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the root selector is open.
   function Root_Selector_Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Return the number of root paths in the selector.
   --
   --  @param Model Model to inspect.
   --  @return Number of root paths.
   function Root_Count
     (Model : Window_Model)
      return Natural;

   --  Return the selected root-selector row.
   --
   --  @param Model Model to inspect.
   --  @return One-based selected root index, or zero when none is selected.
   function Root_Selected_Index
     (Model : Window_Model)
      return Natural;

   --  Set the selected root-selector row.
   --
   --  @param Model Model to update.
   --  @param Index One-based selected root index, or zero for no row.
   procedure Set_Root_Selected_Index
     (Model : in out Window_Model;
      Index : Natural);

   --  Move the selected root-selector row with wraparound.
   --
   --  @param Model Model to update.
   --  @param Direction Direction requested by user input.
   procedure Move_Root_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction);

   --  Return a root path from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root path or an empty string when Index is invalid.
   function Root_Path
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return a root label from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root label or an empty string when Index is invalid.
   function Root_Label
     (Model : Window_Model;
      Index : Positive)
      return String;

   --  Return a root kind from the selector.
   --
   --  @param Model Model to inspect.
   --  @param Index One-based root index.
   --  @return Root kind or Root_Filesystem when Index is invalid.
   function Root_Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind;

   --  Return whether a root entry reports removable media.
   --
   --  @param Model Window model to inspect.
   --  @param Index One-based root selector index.
   --  @return True when Index names a removable root.
   function Root_Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean;

end Files.Model.Root_Selector;
