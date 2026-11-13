--  Which windows take settings another window changed, decided over window
--  revisions alone so the suite can drive it without real windows.
--
--  Every window counts its settings changes (Files.Model.Settings_Revision)
--  and remembers the count as of the last cross-window sync. A window whose
--  count moved since has a change the others have not seen: each of them
--  adopts it once, and every window's mark catches up with its count after
--  the adoption, so the next pass finds nothing to share -- not even a
--  change the adoption itself counted.
package Files.Settings_Sharing is

   --  Share the settings of window Source with every other window in
   --  First .. Last when Source changed them since the last sync; do
   --  nothing otherwise.
   generic
      --  The windows.
      type Window_Set (<>) is limited private;
      --  A window's settings revision now.
      with function Revision (Windows : Window_Set; Index : Positive) return Natural;
      --  A window's settings revision as of the last sync.
      with function Synced_Revision (Windows : Window_Set; Index : Positive) return Natural;
      --  Record that a window is synced at At_Revision.
      with procedure Mark_Synced (Windows : in out Window_Set; Index : Positive; At_Revision : Natural);
      --  Make window Target take the settings of window Source.
      with procedure Adopt (Windows : in out Window_Set; Target : Positive; Source : Positive);
   --  @param Windows The windows.
   --  @param First The first window's index.
   --  @param Last The last window's index; below First for none.
   --  @param Source The window whose change is shared.
   procedure Share_From
     (Windows : in out Window_Set;
      First   : Positive;
      Last    : Natural;
      Source  : Positive);

end Files.Settings_Sharing;
