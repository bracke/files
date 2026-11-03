--  When a window's view snapshot can be reused, when only its scroll offsets
--  need patching, and when it must be rebuilt (Files.Application.Windows'
--  Refresh_Snapshot acts on the answer). Pure, so the rule is tested alone.
package Files.Snapshot_Policy with Pure is

   type Snapshot_Action is
     (Reuse,         --  nothing it shows has changed
      Patch_Scroll,  --  only a scroll offset moved: copy it with the new ones
      Rebuild);      --  the items, the settings or the time it shows moved

   --  @param Valid A snapshot has been built.
   --  @param Same_Minute It was built in this wall-clock minute (relative
   --    times and day bands are read from the clock).
   --  @param Same_Revision The model has not changed since.
   --  @param Same_Settings The snapshot settings have not changed since.
   --  @param Same_Scroll No scroll offset has moved since.
   --  @param Pasting A paste is running, whose progress no revision tracks.
   --  @param Paste_Interval_Elapsed The progress interval has passed since
   --    the build (a running paste is redrawn that often).
   --  @return What to do with the snapshot.
   function Action_For
     (Valid, Same_Minute, Same_Revision, Same_Settings, Same_Scroll : Boolean;
      Pasting, Paste_Interval_Elapsed : Boolean)
      return Snapshot_Action
   is (if Valid and then Same_Minute and then Same_Revision and then Same_Settings
         and then (not Pasting or else not Paste_Interval_Elapsed)
       then (if Same_Scroll then Reuse else Patch_Scroll)
       else Rebuild);

end Files.Snapshot_Policy;
