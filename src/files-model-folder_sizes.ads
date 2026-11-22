with Files.Folder_Size;
--  Recursive folder-size measurements cached for the selected folders.
package Files.Model.Folder_Sizes is

   --  The window's folder-size measurements: a handle the model holds as
   --  data, which Files.Operations drives (targets, steps, cancels) in place,
   --  since a copy is its queues' worth on every loop pass. The model only
   --  releases it, when the view it measures is left.
   --
   --  @param Model Window whose folder-size session is driven.
   --  @param Change Called once with the session, in place.
   procedure Update_Scan
     (Model  : in out Window_Model;
      Change : not null access procedure (Scan : in out Files.Folder_Size.Session));

   --  Record finished measurements, those of directories still selected;
   --  the selected directories are looked up once per batch. A measurement
   --  of a folder as it was before it changed (its listed time is not the
   --  item's) is not recorded but handed back in Stale, with the item's
   --  time, for the caller to measure again.
   --
   --  @param Model Window to update.
   --  @param Measured The finished measurements.
   --  @param Stale The folders to measure again.
   procedure Note
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      Stale    : out Files.Folder_Size.Measurement_Vectors.Vector);

   --  Note, for a caller that measures nothing again.
   --
   --  @param Model Window to update.
   --  @param Measured The finished measurements.
   procedure Note
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector);

   --  Forget every cached folder-size measurement.
   --
   --  @param Model Model to update.
   procedure Clear
     (Model : in out Window_Model);

   --  Drop cached folder-size measurements for directories that are no longer
   --  part of the current selection, keeping the cache bounded to the selection.
   --
   --  @param Model Model to update.
   procedure Prune_To_Selection
     (Model : in out Window_Model);

   --  Return whether a folder-size measurement is cached for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up in the cache.
   --  @return True when a measurement for Path is cached.
   function Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean;

   --  Cached_For for a path as the items hold it, without copying it.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up in the cache.
   --  @return True when a measurement for Path is cached.
   function Cached_For
     (Model : Window_Model;
      Path  : Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   --  The selection's combined size (every selected file's size plus each
   --  selected folder's measured size), as kept by the folder-size
   --  hand-overs. Kept is False when it is not current (the selection,
   --  rows or folder sizes moved since), and the caller sums the selection.
   --
   --  @param Model Model to inspect.
   --  @param Kept True when Bytes and Pending are current.
   --  @param Bytes The combined size (0 when not Kept).
   --  @param Pending True when a selected folder is not measured yet.
   procedure Selection_Total
     (Model   : Window_Model;
      Kept    : out Boolean;
      Bytes   : out Long_Long_Integer;
      Pending : out Boolean);

   --  Return the cached folder-size measurement for Path.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path to look up.
   --  @return Cached totals for Path; Available is False when Path is not cached.
   function Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System_Types.Directory_Size_Result;

   --  Look Path up once: whether it is measured, and its totals. For a
   --  caller that asks for many folders (a selection's total), without the
   --  two lookups and copies of the path Cached_For and Value make.
   --
   --  @param Model Model to inspect.
   --  @param Path Directory path, as the items hold it.
   --  @param Known True when a measurement for Path is cached.
   --  @param Bytes Its total bytes (0 when not Known).
   procedure Find
     (Model : Window_Model;
      Path  : Ada.Strings.Unbounded.Unbounded_String;
      Known : out Boolean;
      Bytes : out Long_Long_Integer);

   --  A number that moves with every change to the folder sizes measured, so
   --  a total computed from them can be kept until it does.
   --
   --  @param Model Model to inspect.
   --  @return The folder sizes' revision.
   function Revision (Model : Window_Model) return Natural;

end Files.Model.Folder_Sizes;
