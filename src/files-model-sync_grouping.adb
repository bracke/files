with Files.Preference_Types;
with Ada.Calendar;
with Files.Grouping;
with Files.Settings.Path_References;
separate (Files.Model)
procedure Sync_Grouping
  (Model    : in out Window_Model;
   Settings : Files.Settings.Settings_Model)
is
   use type Files.Preference_Types.Group_Mode;
   use type Files.Preference_Types.View_Mode;
   Mode : constant Files.Preference_Types.Group_Mode :=
     (if Model.View_Value = Files.Preference_Types.Details then Settings.Group_By
      else Files.Preference_Types.No_Grouping);

   --  The day the modified bands count from. Within the day already banded
   --  by, one clock reading says so; only a new day (or a first banding)
   --  works the calendar out.
   function Current_Day return Ada.Calendar.Time is
      Now : Ada.Calendar.Time;
   begin
      if Mode /= Files.Preference_Types.Group_By_Modified then
         return Model.Grouping.Day;
      end if;
      Now := Ada.Calendar.Clock;
      if Model.Grouping.Day /= Files.Types.Unknown_Time
        and then Now >= Model.Grouping.Day
        and then Now < Model.Grouping.Next_Day
      then
         return Model.Grouping.Day;
      end if;
      return Files.Grouping.Day_Start (Now);
   end Current_Day;

   Today : constant Ada.Calendar.Time := Current_Day;
   Was_Grouped : constant Boolean := Model.Grouping.Mode /= Files.Preference_Types.No_Grouping;
   Inputs_Changed : constant Boolean :=
     Mode /= Model.Grouping.Mode
     or else (Mode = Files.Preference_Types.Group_By_Label
              and then not Files.Settings.Path_References.Same_Labels (Settings, Model.Grouping.Labels))
     or else Today /= Model.Grouping.Day;
begin
   if not Inputs_Changed and then Model.Grouping.Banded then
      return;
   end if;
   if Inputs_Changed then
      Model.Grouping.Mode := Mode;
      Model.Grouping.Day := Today;
      --  Thirty-six hours on from a midnight is always the next calendar
      --  day, whatever a daylight-saving change does to the day's length.
      Model.Grouping.Next_Day :=
        (if Today = Files.Types.Unknown_Time then Files.Types.Unknown_Time
         else Files.Grouping.Day_Start (Today + 36.0 * 3600.0));
      if Mode = Files.Preference_Types.Group_By_Label then
         Model.Grouping.Labels := Files.Settings.Path_References.Path_Labels (Settings);
      else
         Model.Grouping.Labels.Clear;
      end if;
   end if;
   --  A changed grouping re-sorts, so each band holds the plain sort order
   --  and leaving a grouping restores it; the Recent view keeps its recency
   --  order and is only partitioned. Otherwise only replaced items (a new
   --  listing, a navigation) need regrouping, and a reload already sorted.
   if Inputs_Changed
     and then (Was_Grouped or else Mode /= Files.Preference_Types.No_Grouping)
     and then not Model.Recent_View_Active
   then
      Resort_Items (Model);
   else
      --  Returns at once when the items are already in band order.
      Resort_Items (Model, Field_Sort => False);
   end if;
   Model.Grouping.Banded := True;
end Sync_Grouping;
