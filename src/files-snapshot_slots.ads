with Ada.Real_Time;
with Files.Model;
with Files.Rendering;
with Files.Settings;

--  A window's two view snapshots and the bookkeeping that keeps them current
--  cheaply: Snapshots (Current_Slot) is the model as it is now, for the render
--  and for every input handler that lays the view out; Snapshots (Drawn_Slot)
--  is the one the frame on screen was built from, which clicks are hit-tested
--  against. They are one slot until the model changes between frames; a
--  change is then built into the other slot, so the drawn snapshot survives
--  until the next render draws the new one. Kept apart from the window (no
--  GLFW) so the bookkeeping can be tested.
package Files.Snapshot_Slots is

   type Snapshot_Slot is range 1 .. 2;
   type Snapshot_Slot_Array is array (Snapshot_Slot) of Files.Rendering.View_Snapshot;
   type Slot_Number_Array is array (Snapshot_Slot) of Natural;

   type View_Slots is record
      Snapshots       : Snapshot_Slot_Array;
      --  The model's rows revision each slot was built at: a click on a
      --  drawn item whose rows have changed since (a new listing, a sort, a
      --  regroup) is matched by path.
      Slot_Model_Rows : Slot_Number_Array := [others => 0];
      --  Which build each slot holds (Slot_Contents: everything but the
      --  scroll offsets; Slot_Rows: its items). Equal numbers mean equal
      --  contents, so a patch into the other slot need not copy it first.
      Slot_Contents   : Slot_Number_Array := [others => 0];
      Slot_Rows       : Slot_Number_Array := [others => 0];
      Last_Generation : Natural := 0;
      Current_Slot    : Snapshot_Slot := 1;
      Drawn_Slot      : Snapshot_Slot := 1;
      --  False until the first build and after any change the keys below do
      --  not see (a replaced model).
      Snapshot_Valid  : Boolean := False;
      --  When the current snapshot was built: during a paste its progress is
      --  redrawn at most every Paste_Progress_Interval.
      Snapshot_Built_At : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  Model revision the current snapshot was built at. It is reused only
      --  while the model's revision still matches, so a background poll (file
      --  watch, folder sizes) that changed nothing forces no O(items) rebuild.
      Cached_Model_Revision : Natural := 0;
      --  Scroll revision the current snapshot's offsets were taken at.
      Cached_Scroll_Revision : Natural := 0;
      --  Rows revision its rows were built at (Files.Model.Rows_Revision).
      Cached_Rows_Revision : Natural := 0;
      --  Snapshot-relevant settings (theme, columns, visibility, favorites,
      --  labels) the current snapshot was built with. With the model revision
      --  these are the whole of Build_Snapshot's inputs, so the snapshot is
      --  reused only while both still match -- no explicit invalidation.
      Cached_Settings_Key  : Files.Settings.Snapshot_Settings_Key;
   end record;

   --  Ten progress updates a second: a rebuild is O(items), and on every
   --  loop pass it held a core for the length of a paste in a large folder.
   Paste_Progress_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (100);

   --  Bring Snapshots (Current_Slot) up to date with Model and Settings, as
   --  cheaply as Files.Snapshot_Policy allows: reused, offsets patched, rows
   --  kept, or rebuilt -- into the other slot when the current one is drawn.
   --
   --  @param View The window's snapshots.
   --  @param Model The window's model.
   --  @param Settings The live settings.
   --  @param Now The current time.
   procedure Refresh
     (View     : in out View_Slots;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Now      : Ada.Real_Time.Time);

   --  The other slot.
   --
   --  @param Slot One slot.
   --  @return The other.
   function Other (Slot : Snapshot_Slot) return Snapshot_Slot is (if Slot = 1 then 2 else 1);

end Files.Snapshot_Slots;
