with Ada.Calendar;
with Files.Grouping;
separate (Files.Model)
procedure Sync_Grouping
  (Model    : in out Window_Model;
   Settings : Files.Settings.Settings_Model)
is
   use type Ada.Calendar.Time;
   use type Files.Settings.Path_Label_Vectors.Vector;
   use type Files.Types.Group_Mode;
   use type Files.Types.View_Mode;
   Mode : constant Files.Types.Group_Mode :=
     (if Model.View_Value = Files.Types.Details then Settings.Group_By else Files.Types.No_Grouping);
   Today : constant Ada.Calendar.Time :=
     (if Mode = Files.Types.Group_By_Modified
      then Files.Grouping.Day_Start (Ada.Calendar.Clock)
      else Model.Group_Day);
   Was_Grouped : constant Boolean := Model.Group_Mode_Value /= Files.Types.No_Grouping;
   Inputs_Changed : constant Boolean :=
     Mode /= Model.Group_Mode_Value
     or else (Mode = Files.Types.Group_By_Label and then Settings.Labels /= Model.Group_Labels)
     or else Today /= Model.Group_Day;
begin
   if not Inputs_Changed and then Model.Revision_Value = Model.Group_Synced_Revision then
      return;
   end if;
   if Inputs_Changed then
      Model.Group_Mode_Value := Mode;
      Model.Group_Day := Today;
      if Mode = Files.Types.Group_By_Label then
         Model.Group_Labels := Settings.Labels;
      else
         Model.Group_Labels.Clear;
      end if;
   end if;
   --  A changed grouping re-sorts, so each band holds the plain sort order
   --  and leaving a grouping restores it; the Recent view keeps its recency
   --  order and is only partitioned. Otherwise only a reload or edit that
   --  broke the band order needs regrouping, and a reload already sorted.
   if Inputs_Changed
     and then (Was_Grouped or else Mode /= Files.Types.No_Grouping)
     and then not Model.Recent_View_Active
   then
      Resort_Items (Model);
   elsif not Items_In_Group_Order (Model) then
      Resort_Items (Model, Field_Sort => False);
   end if;
   Model.Group_Synced_Revision := Model.Revision_Value;
end Sync_Grouping;
