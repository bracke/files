--  When a window's view snapshot can be reused, when only its scroll offsets
--  need patching, and when it must be rebuilt (Files.Application.Windows'
--  Refresh_Snapshot acts on the answer). Pure, so the rule is tested alone.
package Files.Snapshot_Policy with Pure is

   type Snapshot_Action is
     (Reuse,         --  nothing it shows has changed
      Patch_Scroll,  --  only a scroll offset moved: copy it with the new ones
      Patch_Rows,    --  the rows stand but for which are selected: keep them
      Rebuild);      --  the items, the settings or the time it shows moved

   --  Nothing a snapshot holds depends on the clock: relative times are
   --  formatted when the frame is built (its cache keys the minute), and a
   --  new day that moves the date bands reorders the items, which moves the
   --  rows revision.
   --
   --  @param Valid A snapshot has been built.
   --  @param Same_Revision The model has not changed since.
   --  @param Same_Settings The snapshot settings have not changed since.
   --  @param Same_Scroll No scroll offset has moved since.
   --  @param Same_Rows The model's rows have not changed since but for the
   --    selection (Files.Model.Rows_Revision).
   --  @param Same_Row_Settings The settings the rows read have not changed
   --    (Files.Settings.Same_Row_Settings): a column drag keeps them.
   --  @param Pasting A paste is running: its progress (header only) is
   --    redrawn at most once per interval.
   --  @param Paste_Interval_Elapsed The progress interval has passed since
   --    the build.
   --  @return What to do with the snapshot.
   function Action_For
     (Valid, Same_Revision, Same_Settings, Same_Scroll : Boolean;
      Same_Rows, Same_Row_Settings : Boolean;
      Pasting, Paste_Interval_Elapsed : Boolean)
      return Snapshot_Action
   is (if not Valid then Rebuild
       --  A paste's progress moves the revision with every item; it waits
       --  for the interval unless the rows themselves changed.
       elsif Pasting and then not Paste_Interval_Elapsed
         and then Same_Rows and then Same_Row_Settings and then Same_Settings
       then (if Same_Scroll then Reuse else Patch_Scroll)
       elsif Same_Revision and then Same_Settings and then not Pasting
       then (if Same_Scroll then Reuse else Patch_Scroll)
       elsif Same_Rows and then Same_Row_Settings then Patch_Rows
       else Rebuild);

end Files.Snapshot_Policy;
