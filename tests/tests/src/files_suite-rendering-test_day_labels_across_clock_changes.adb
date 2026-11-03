with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Files.Display_Text;
separate (Files_Suite.Rendering)
   --  A day is 23 or 25 hours across a daylight-saving change; counting
   --  86,400-second steps back from midnight missed "yesterday" and the
   --  weekdays the day after one, and they fell back to the full date. Dates
   --  around the North American (8 March 2026) and European (29 March 2026)
   --  changes, so the suite's St. John's and Berlin runs both cross one.
   procedure Test_Day_Labels_Across_Clock_Changes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Local (Day : Ada.Calendar.Day_Number; Hour : Natural) return Ada.Calendar.Time is
        (Ada.Calendar.Time_Of (2026, 3, Day, Duration (Hour * 3_600)));

      procedure Check (Change_Day : Ada.Calendar.Day_Number; Where : String) is
      begin
         for Back in 1 .. 6 loop
            declare
               Now   : constant Ada.Calendar.Time := Local (Change_Day + 1, 12);
               Value : constant Ada.Calendar.Time := Local (Change_Day + 1 - Back, 8);
            begin
               Files_Suite.Support.Assert_Equal
                 (Files.Display_Text.Calendar_Days_Ago (Value, Now), Back,
                  Where & ": the calendar days back across the change");
               Assert
                 (Files.Display_Text.Humanized_Time_Text (Value, Now)
                  /= Files.Display_Text.Full_Time_Text (Value),
                  Where & ":" & Back'Image & " days back is shown relative, not as the full date");
            end;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Files.Display_Text.Calendar_Days_Ago (Local (Change_Day + 2, 8), Local (Change_Day + 1, 12)), -1,
            Where & ": tomorrow is a day ahead");
      end Check;

      --  Whether the local zone's offset differs across Change_Day: only
      --  then does the check above cross a clock change.
      function Crosses (Change_Day : Ada.Calendar.Day_Number) return Boolean is
         use type Ada.Calendar.Time_Zones.Time_Offset;
      begin
         return Ada.Calendar.Time_Zones.UTC_Time_Offset (Local (Change_Day - 5, 8))
           /= Ada.Calendar.Time_Zones.UTC_Time_Offset (Local (Change_Day + 1, 12));
      end Crosses;
   begin
      if not Crosses (8) and then not Crosses (29) then
         Files_Suite.Support.Skip
           ("Test_Day_Labels_Across_Clock_Changes", "the local zone has no clock change in March 2026");
         return;
      end if;
      Check (8, "North America");
      Check (29, "Europe");
   end Test_Day_Labels_Across_Clock_Changes;
