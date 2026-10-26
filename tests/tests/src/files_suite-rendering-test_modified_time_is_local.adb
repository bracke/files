separate (Files_Suite.Rendering)
   --  Ada.Calendar.Time_Of reads its fields as local time, so a file stamped
   --  09:30 here must show 09:30 -- not that moment's UTC clock.
   procedure Test_Modified_Time_Is_Local (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time_Zones.Time_Offset;
      Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);
      Frame    : Frame_Commands;
      Stamp    : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (2025, 1, 15, Duration (9 * 3_600 + 30 * 60 + 12));
   begin
      --  Where local time is UTC the two clocks agree and nothing is shown.
      if Ada.Calendar.Time_Zones.UTC_Time_Offset (Stamp) = 0 then
         Files_Suite.Support.Skip ("Test_Modified_Time_Is_Local", "local time is UTC here");
         return;
      end if;
      Snapshot.Items (1).Modified_Available := True;
      Snapshot.Items (1).Modified_Time := Stamp;
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      --  The column may clip the seconds; the hour is what a time zone moves.
      Assert (Frame_Has_Text (Frame, "Jan 15, 2025 9:30"), "an older file shows its local clock time");
   end Test_Modified_Time_Is_Local;
