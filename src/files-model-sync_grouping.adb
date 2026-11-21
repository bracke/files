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
   Today : constant Ada.Calendar.Time :=
     (if Mode = Files.Preference_Types.Group_By_Modified
      then Files.Grouping.Day_Start (Ada.Calendar.Clock)
      else Model.Grouping.Day);
   Was_Grouped : constant Boolean := Model.Grouping.Mode /= Files.Preference_Types.No_Grouping;
   Inputs_Changed : constant Boolean :=
     Mode /= Model.Grouping.Mode
     or else (Mode = Files.Preference_Types.Group_By_Label
              and then not Files.Settings.Path_References.Same_Labels (Settings, Model.Grouping.Labels))
     or else Today /= Model.Grouping.Day;
begin
   if not Inputs_Changed and then Model.Rows_Revision_Value = Model.Grouping.Synced_Revision then
      return;
   end if;
   if Inputs_Changed then
      Model.Grouping.Mode := Mode;
      Model.Grouping.Day := Today;
      if Mode = Files.Preference_Types.Group_By_Label then
         Model.Grouping.Labels := Files.Settings.Path_References.Path_Labels (Settings);
      else
         Model.Grouping.Labels.Clear;
      end if;
   end if;
   --  A changed grouping re-sorts, so each band holds the plain sort order
   --  and leaving a grouping restores it; the Recent view keeps its recency
   --  order and is only partitioned. Otherwise only a reload or edit that
   --  broke the band order needs regrouping, and a reload already sorted.
   if Inputs_Changed
     and then (Was_Grouped or else Mode /= Files.Preference_Types.No_Grouping)
     and then not Model.Recent_View_Active
   then
      Resort_Items (Model);
   else
      --  Returns at once when the items are already in band order.
      Resort_Items (Model, Field_Sort => False);
   end if;
   Model.Grouping.Synced_Revision := Model.Rows_Revision_Value;
end Sync_Grouping;
