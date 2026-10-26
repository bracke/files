separate (Files_Suite.Rendering)
   --  A file stamped centuries from now (touch -d 2390-01-01 is legal) does
   --  not break the frame: subtracting times that far apart overflows
   --  Duration, and a frame that raised was never drawn again.
   procedure Test_Far_Future_Modified_Time (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);
      Frame    : Frame_Commands;
   begin
      Snapshot.Items (1).Modified_Available := True;
      Snapshot.Items (1).Modified_Time := Ada.Calendar.Time_Of (2390, 1, 1, 0.0);
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Assert (not Frame.Text.Is_Empty, "the frame is built");
      Assert (Frame_Has_Text (Frame, "2390"), "and shows the date");
   end Test_Far_Future_Modified_Time;
