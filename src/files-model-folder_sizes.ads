--  The folder sizes state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Folder_Sizes is

   --  Cache a recursive folder-size measurement for a directory path.
   --
   --  The cache holds one measurement at a time, keyed by Path, so a repeated
   --  selection of the same directory reuses it instead of walking again.
   --
   --  @param Model Model to update.
   --  @param Path Directory the measurement describes.
   --  @param Value Recursive size totals for Path.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result);

   --  Forget every cached folder-size measurement.
   --
   --  @param Model Model to update.
   procedure Clear_Folder_Size
     (Model : in out Window_Model);

   --  Drop cached folder-size measurements for directories that are no longer
   --  part of the current selection, keeping the cache bounded to the selection.
   --
   --  @param Model Model to update.
   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model);

   --  Return whether a folder-size measurement is cached for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up in the cache.
   --  @return True when a measurement for Path is cached.
   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean;

   --  Return the cached folder-size measurement for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up.
   --  @return Cached totals for Path; Available is False when Path is not cached.
   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result;

end Files.Model.Folder_Sizes;
