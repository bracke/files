with Ada.Calendar.Time_Zones;
with Files.Preference_Types;
separate (Files_Suite.Model)
   --  "This week" began 6 x 86,400 seconds before today's midnight, which
   --  across a daylight-saving change is an hour off the midnight six days
   --  back: an item from late on the day before the week counted in it, or
   --  one from just after its midnight did not. The week now starts at that
   --  midnight. The suite runs at TZ=America/St_Johns, where daylight
   --  saving began on 9 March 2025 and ended on 2 November 2025; Europe's
   --  clocks changed on 30 March and 26 October 2025, and a week across
   --  each is checked too. The same answers hold in any zone, but one where
   --  no week crosses a change tests nothing, so it skips.
   procedure Test_Grouping_Week_Across_Dst (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Hour : constant Duration := 3_600.0;

      --  Seconds into the local day Year-Month-Day.
      function Local
        (Year : Ada.Calendar.Year_Number; Month : Ada.Calendar.Month_Number; Day : Ada.Calendar.Day_Number;
         Seconds : Ada.Calendar.Day_Duration) return Ada.Calendar.Time is
        (Ada.Calendar.Time_Of (Year, Month, Day, Seconds));

      --  The band of At_Time when today is Today's local day.
      function Band (At_Time, Today : Ada.Calendar.Time) return Positive is
        (Files.Grouping.Band_Of
           (Files.Preference_Types.Group_By_Modified, Files.Types.Regular_File_Item, "", True, At_Time, False, 0,
            Files.Preference_Types.No_Label, Files.Grouping.Day_Start (Today)));

      Spring : constant Ada.Calendar.Time := Local (2025, 3, 12, 12.0 * Hour);
      Autumn : constant Ada.Calendar.Time := Local (2025, 11, 5, 12.0 * Hour);
      Europe_Spring : constant Ada.Calendar.Time := Local (2025, 4, 2, 12.0 * Hour);
      Europe_Autumn : constant Ada.Calendar.Time := Local (2025, 10, 29, 12.0 * Hour);

      --  Whether the local offset differs between the week's start and today.
      function Crosses (Week_Start, Today : Ada.Calendar.Time) return Boolean is
         use type Ada.Calendar.Time_Zones.Time_Offset;
      begin
         return Ada.Calendar.Time_Zones.UTC_Time_Offset (Week_Start)
           /= Ada.Calendar.Time_Zones.UTC_Time_Offset (Today);
      end Crosses;
   begin
      if not Crosses (Local (2025, 3, 6, 0.5 * Hour), Spring)
        and then not Crosses (Local (2025, 10, 30, 0.5 * Hour), Autumn)
        and then not Crosses (Local (2025, 3, 27, 0.5 * Hour), Europe_Spring)
        and then not Crosses (Local (2025, 10, 23, 0.5 * Hour), Europe_Autumn)
      then
         Files_Suite.Support.Skip
           ("Test_Grouping_Week_Across_Dst", "the local zone changed no clock in the weeks checked");
         return;
      end if;
      --  Spring: today is 12 March, the week starts at midnight on 6 March,
      --  and the clocks went forward on 9 March, in between.
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 3, 5, 23.5 * Hour), Spring), 3, "half an hour before the week is earlier (spring)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 3, 6, 0.5 * Hour), Spring), 2, "half an hour into it is this week (spring)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 3, 11, 23.5 * Hour), Spring), 2, "yesterday is this week (spring)");

      --  Autumn: today is 5 November, the week starts at midnight on
      --  30 October, and the clocks went back on 2 November, in between.
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 10, 29, 23.5 * Hour), Autumn), 3, "half an hour before the week is earlier (autumn)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 10, 30, 0.5 * Hour), Autumn), 2, "half an hour into it is this week (autumn)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 11, 4, 23.5 * Hour), Autumn), 2, "yesterday is this week (autumn)");

      --  Europe: today is 2 April, the week starts at midnight on 27 March,
      --  and the clocks went forward on 30 March, in between.
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 3, 26, 23.5 * Hour), Europe_Spring), 3,
         "half an hour before the week is earlier (European spring)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 3, 27, 0.5 * Hour), Europe_Spring), 2,
         "half an hour into it is this week (European spring)");

      --  Today is 29 October, the week starts at midnight on 23 October, and
      --  the clocks went back on 26 October, in between.
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 10, 22, 23.5 * Hour), Europe_Autumn), 3,
         "half an hour before the week is earlier (European autumn)");
      Files_Suite.Support.Assert_Equal
        (Band (Local (2025, 10, 23, 0.5 * Hour), Europe_Autumn), 2,
         "half an hour into it is this week (European autumn)");
   end Test_Grouping_Week_Across_Dst;
