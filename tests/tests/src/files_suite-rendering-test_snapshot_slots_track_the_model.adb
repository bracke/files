with Ada.Real_Time;
with Files.Snapshot_Slots;
separate (Files_Suite.Rendering)
   --  The window's two snapshots: after every kind of change, drawn between
   --  changes or not, the current one is what a rebuild gives, and the one on
   --  screen is left as it was drawn until the next frame.
   procedure Test_Snapshot_Slots_Track_The_Model (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Snapshot_Slots.Snapshot_Slot;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      View     : Files.Snapshot_Slots.View_Slots;

      --  Refresh as the window does, then compare; Draw puts the current
      --  slot on screen afterwards, as a render would.
      procedure Step (Name : String; Change : not null access procedure; Draw : Boolean) is
         Drawn_Before : constant View_Snapshot := View.Snapshots (View.Drawn_Slot);
         Was_Valid    : constant Boolean := View.Snapshot_Valid;
      begin
         Change.all;
         Files.Snapshot_Slots.Refresh (View, Model, Settings, Ada.Real_Time.Clock);
         Assert (View.Snapshots (View.Current_Slot) = Build_Snapshot (Model, Settings),
                 Name & ": the current snapshot is the one a rebuild gives");
         if Was_Valid and then View.Current_Slot /= View.Drawn_Slot then
            Assert (View.Snapshots (View.Drawn_Slot) = Drawn_Before,
                    Name & ": the snapshot on screen is left as it was drawn");
         end if;
         if Draw then
            View.Drawn_Slot := View.Current_Slot;
         end if;
      end Step;

      procedure Nothing is null;
      procedure Scroll_Down is begin Files.Model.Set_Main_View_Scroll_Lines (Model, 10); end Scroll_Down;
      procedure Scroll_Up is begin Files.Model.Set_Main_View_Scroll_Lines (Model, 0); end Scroll_Up;
      procedure Pick is begin Files.Model.Selection.Select_Visible (Model, 3); end Pick;
      procedure Pick_Other is begin Files.Model.Selection.Toggle_Visible_Selection (Model, 7); end Pick_Other;
      procedure Filter is begin Files.Model.Set_Filter (Model, "1"); end Filter;
      procedure Unfilter is begin Files.Model.Clear_Filter (Model); end Unfilter;
      procedure Resort is begin Files.Model.Select_Sort_Field (Model, Files.Types.Sort_Size); end Resort;
      --  Settings the rows do not show (the space bar, a column's width),
      --  and ones they do (extensions, a label): the slots must follow both.
      procedure Space_Bar is begin Settings.Show_Space_Bar := not Settings.Show_Space_Bar; end Space_Bar;
      procedure Widen is
      begin
         Settings.Column_Widths (Files.Types.Size_Column) := Settings.Column_Widths (Files.Types.Size_Column) + 7;
      end Widen;
      procedure Extensions is
      begin
         Settings.Show_File_Extensions := not Settings.Show_File_Extensions;
      end Extensions;
      procedure Label is
      begin
         Files.Settings.Set_Label
           (Settings, To_String (Files.Model.Visible_Item (Model, 2).Full_Path), Files.Types.Green);
      end Label;
   begin
      for I in 1 .. 60 loop
         Items.Append
           (Files.File_System.Make_Item (Files_Suite.Support.Root, "item" & I'Image, Files.Types.Regular_File_Item,
                                         "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      for Draw in Boolean loop
         declare
            Mode : constant String := (if Draw then "drawn each step: " else "not drawn: ");
         begin
            Step (Mode & "first build", Nothing'Access, Draw);
            Step (Mode & "unchanged", Nothing'Access, Draw);
            Step (Mode & "scroll down", Scroll_Down'Access, Draw);
            Step (Mode & "select", Pick'Access, Draw);
            Step (Mode & "scroll back", Scroll_Up'Access, Draw);
            Step (Mode & "scroll down again", Scroll_Down'Access, Draw);
            Step (Mode & "another selection", Pick_Other'Access, Draw);
            Step (Mode & "filter", Filter'Access, Draw);
            Step (Mode & "select under the filter", Pick'Access, Draw);
            Step (Mode & "scroll back once more", Scroll_Up'Access, Draw);
            Step (Mode & "filter cleared", Unfilter'Access, Draw);
            Step (Mode & "sorted", Resort'Access, Draw);
            Step (Mode & "selected after the sort", Pick'Access, Draw);
            Step (Mode & "space bar toggled", Space_Bar'Access, Draw);
            Step (Mode & "selected after it", Pick_Other'Access, Draw);
            Step (Mode & "a column widened", Widen'Access, Draw);
            Step (Mode & "extensions toggled", Extensions'Access, Draw);
            Step (Mode & "selected after that", Pick'Access, Draw);
            Step (Mode & "an item labelled", Label'Access, Draw);
            Step (Mode & "scrolled after the label", Scroll_Down'Access, Draw);
            Step (Mode & "selected after the label", Pick_Other'Access, Draw);
         end;
      end loop;
   end Test_Snapshot_Slots_Track_The_Model;
