with Files.Model.Info_Pane;
with Files.Snapshot_Policy;
with Files.Timing;
with Files.Model.Tree_Panel;

package body Files.Application.Snapshot_Slots is

   package Settings_Keys renames Files.Snapshot_Policy.Settings_Keys;

   procedure Refresh
     (View     : in out View_Slots;
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Now      : Ada.Real_Time.Time;
      Wall_Now : Ada.Calendar.Time)
   is
      use type Ada.Calendar.Time;
      Minute : constant Ada.Calendar.Time := Files.Timing.Minute_Start (Wall_Now);
      Action : constant Files.Snapshot_Policy.Snapshot_Action :=
        Files.Snapshot_Policy.Action_For
          (Valid         => View.Snapshot_Valid,
           Same_Revision => View.Cached_Model_Revision = Files.Model.Revision (Model),
           Same_Settings => Settings_Keys.Same_Snapshot_Settings (Settings, View.Cached_Settings_Key),
           Same_Scroll   => View.Cached_Scroll_Revision = Files.Model.Scroll_Revision (Model),
           Same_Minute   => View.Cached_Minute = Minute,
           Same_Rows     => View.Cached_Rows_Revision = Files.Model.Rows_Revision (Model),
           Same_Row_Settings => Settings_Keys.Same_Row_Settings (Settings, View.Cached_Settings_Key),
           Pasting       => Files.Model.Foreground_Job_Is_Active (Model),
           Paste_Interval_Elapsed =>
             Files.Timing.Elapsed (Now, View.Snapshot_Built_At, Paste_Progress_Interval));
      use type Files.Snapshot_Policy.Snapshot_Action;
   begin
      if Action in Files.Snapshot_Policy.Reuse | Files.Snapshot_Policy.Patch_Scroll then
         if Action = Files.Snapshot_Policy.Patch_Scroll then
            --  Only an offset moved: the items stand. A copy with the new
            --  offsets (about a millisecond for 20,000 items) instead of a
            --  rebuild (thirty), into the other slot if this one is on screen.
            if View.Current_Slot = View.Drawn_Slot then
               declare
                  Spare : constant Snapshot_Slot := Other (View.Drawn_Slot);
               begin
                  --  A scroll back and forth finds the other slot already
                  --  holding this build: only its offsets are written below.
                  if View.Slot_Contents (Spare) /= View.Slot_Contents (View.Current_Slot) then
                     View.Snapshots (Spare) := View.Snapshots (View.Current_Slot);
                     View.Slot_Model_Rows (Spare) := View.Slot_Model_Rows (View.Current_Slot);
                     View.Slot_Contents (Spare) := View.Slot_Contents (View.Current_Slot);
                     View.Slot_Rows (Spare) := View.Slot_Rows (View.Current_Slot);
                  end if;
                  View.Current_Slot := Spare;
               end;
            end if;
            View.Snapshots (View.Current_Slot).Main_View_Scroll_Lines := Files.Model.Main_View_Scroll_Lines (Model);
            View.Snapshots (View.Current_Slot).Info_Pane_Scroll_Lines :=
              Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model);
            View.Snapshots (View.Current_Slot).Tree_Panel_Scroll_Rows := Files.Model.Tree_Panel.Scroll_Rows (Model);
            View.Cached_Scroll_Revision := Files.Model.Scroll_Revision (Model);
         end if;
         return;
      end if;

      declare
         --  A selection change keeps the rows (a few milliseconds instead of
         --  a whole rebuild in a large folder), taken from the current slot.
         --  Built in place: a snapshot's copy is milliseconds of its own.
         From      : constant Snapshot_Slot := View.Current_Slot;
         Keep_Rows : constant Boolean := Action = Files.Snapshot_Policy.Patch_Rows;
      begin
         if View.Current_Slot = View.Drawn_Slot then
            View.Current_Slot := Other (View.Drawn_Slot);
            if Keep_Rows and then View.Slot_Rows (View.Current_Slot) /= View.Slot_Rows (From) then
               --  With what is kept with them: a total from this slot's
               --  older rows could count sizes since reloaded.
               Files.Rendering.Copy_Rows (View.Snapshots (View.Current_Slot), View.Snapshots (From));
            end if;
         end if;
         Files.Rendering.Build_Snapshot_Into (View.Snapshots (View.Current_Slot), Model, Settings, Minute, Keep_Rows);
         View.Last_Generation := View.Last_Generation + 1;
         View.Slot_Contents (View.Current_Slot) := View.Last_Generation;
         View.Slot_Rows (View.Current_Slot) :=
           (if Keep_Rows then View.Slot_Rows (From) else View.Last_Generation);
      end;
      View.Cached_Rows_Revision := Files.Model.Rows_Revision (Model);
      View.Cached_Scroll_Revision := Files.Model.Scroll_Revision (Model);
      View.Slot_Model_Rows (View.Current_Slot) := Files.Model.Rows_Revision (Model);
      View.Cached_Model_Revision := Files.Model.Revision (Model);
      View.Cached_Settings_Key := Settings_Keys.Snapshot_Settings_Key_Of (Settings);
      View.Snapshot_Built_At := Now;
      View.Cached_Minute := Minute;
      View.Snapshot_Valid := True;
   end Refresh;

end Files.Application.Snapshot_Slots;
