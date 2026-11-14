--  Recursive folder-size measurements cached for the selected folders.
package Files.Model.Folder_Sizes is

   --  The window's folder-size measurements: a handle the model holds as
   --  data, which Files.Operations drives (targets, steps, cancels) in place,
   --  since a copy is its queues' worth on every loop pass. The model only
   --  releases it, when the view it measures is left.
   --
   --  @param Model Window whose folder-size session is driven.
   --  @param Change Called once with the session, in place.
   procedure Update_Folder_Scan
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
   procedure Note_Folder_Sizes
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      Stale    : out Files.Folder_Size.Measurement_Vectors.Vector);

   --  Note_Folder_Sizes, for a caller that measures nothing again.
   --
   --  @param Model Window to update.
   --  @param Measured The finished measurements.
   procedure Note_Folder_Sizes
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector);

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
