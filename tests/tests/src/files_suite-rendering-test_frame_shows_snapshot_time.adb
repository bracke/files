with Files.Display_Text;
separate (Files_Suite.Rendering)
   --  A frame is a function of its snapshot: the relative times it draws are
   --  against the snapshot's minute, so the same snapshot draws the same
   --  frame whenever it is drawn, and a snapshot of a later day draws them
   --  against that day.
   procedure Test_Frame_Shows_Snapshot_Time (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Stamp    : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (2025, 3, 12, Duration (10 * 3_600));
      --  Two hours after the stamp, and twenty days after it.
      Same_Day : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (2025, 3, 12, Duration (12 * 3_600 + 17));
      Later    : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (2025, 4, 1, Duration (12 * 3_600));

      function Frame_At (Now : Ada.Calendar.Time) return Frame_Commands is
         Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);
      begin
         Snapshot.Now := Now;
         Snapshot.Items (1).Modified_Available := True;
         Snapshot.Items (1).Modified_Time := Stamp;
         return Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      end Frame_At;

      First  : constant Frame_Commands := Frame_At (Same_Day);
      Again  : constant Frame_Commands := Frame_At (Same_Day);
      Moved  : constant Frame_Commands := Frame_At (Later);
      Today  : constant String := Files.Display_Text.Humanized_Time_Text (Stamp, Same_Day);
      Dated  : constant String := Files.Display_Text.Humanized_Time_Text (Stamp, Later);
      --  The date's start: the column can clip the clock time after it.
      Date   : constant String := Dated (Dated'First .. Dated'First + Natural'Min (9, Dated'Length - 1));
   begin
      Assert (Today /= Dated, "the stamp reads differently on its own day and twenty days on");
      Assert (First = Again, "the same snapshot draws the same frame");
      Assert (Frame_Has_Text (First, Today), "the time is drawn against the snapshot's day: " & Today);
      Assert (Frame_Has_Text (Moved, Date), "a later snapshot draws it against its own day: " & Dated);
      Assert (not Frame_Has_Text (Moved, Today), "and not against the earlier one");
      Assert (not Frame_Has_Text (First, Date), "while the earlier snapshot shows no date");
   end Test_Frame_Shows_Snapshot_Time;
