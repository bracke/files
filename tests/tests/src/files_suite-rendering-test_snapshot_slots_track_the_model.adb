with Files.Model.Filtering;
with Files.Preference_Types;
with Files.Model.Command_Palette;
with Guikit.Input;
with Ada.Calendar;
with Ada.Real_Time;
with Files.Rendering.Testing;
with Files.Application.Snapshot_Slots;
with Files.Settings.Path_References;
with Files_Suite.Support.Disk;
separate (Files_Suite.Rendering)
   --  The window's two snapshots: after every kind of change, drawn between
   --  changes or not, the current one is what a rebuild gives, and the one on
   --  screen is left as it was drawn until the next frame.
   procedure Test_Snapshot_Slots_Track_The_Model (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Application.Snapshot_Slots.Snapshot_Slot;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      View     : Files.Application.Snapshot_Slots.View_Slots;
      --  One wall-clock time throughout, so a minute turning over mid-test
      --  cannot make a refresh and the rebuild it is compared with differ.
      Wall     : constant Ada.Calendar.Time := Ada.Calendar.Clock;

      --  Refresh as the window does, then compare; Draw puts the current
      --  slot on screen afterwards, as a render would.
      procedure Step (Name : String; Change : not null access procedure; Draw : Boolean) is
         Drawn_Before : constant View_Snapshot := View.Snapshots (View.Drawn_Slot);
         Was_Valid    : constant Boolean := View.Snapshot_Valid;
      begin
         Change.all;
         --  As the window loop does before any step reads the items.
         Files.Model.Sync_Grouping (Model, Settings);
         Files.Application.Snapshot_Slots.Refresh (View, Model, Settings, Ada.Real_Time.Clock, Wall);
         Assert (View.Snapshots (View.Current_Slot) = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Wall),
                 Name & ": the current snapshot is the one a rebuild gives");
         if Was_Valid and then View.Current_Slot /= View.Drawn_Slot then
            Assert (View.Snapshots (View.Drawn_Slot) = Drawn_Before,
                    Name & ": the snapshot on screen is left as it was drawn");
         end if;
         if Draw then
            View.Drawn_Slot := View.Current_Slot;
         end if;
      end Step;

      --  A change no row shows: the snapshot follows it, and the rows
      --  revision stays put, so a large folder's rows are not built again.
      procedure Header_Step (Name : String; Change : not null access procedure; Draw : Boolean) is
         Rows : constant Natural := Files.Model.Rows_Revision (Model);
      begin
         Step (Name, Change, Draw);
         Assert (Files.Model.Rows_Revision (Model) = Rows, Name & ": the rows revision stays put");
      end Header_Step;

      --  Each visible item's row, as a reveal and a drag preview look it up,
      --  is the row that shows it, group headers between them or not.
      procedure Check_Rows (Name : String) is
         Snap : View_Snapshot renames View.Snapshots (View.Current_Slot);
      begin
         for Visible in 1 .. Files.Model.Visible_Count (Model) loop
            declare
               Row : constant Natural := Files.Rendering.Layouts.Row_Position_Of (Snap, Visible);
            begin
               Assert (Row in 1 .. Natural (Snap.Items.Length) and then Snap.Items (Row).Visible_Index = Visible,
                       Name & ": visible item" & Visible'Image & " is found at its row");
            end;
         end loop;
      end Check_Rows;

      procedure Nothing is null;
      procedure Palette_Open is begin Files.Model.Command_Palette.Open (Model); end Palette_Open;
      procedure Palette_Type is begin Files.Model.Command_Palette.Set_Query (Model, "co"); end Palette_Type;
      procedure Palette_Move is begin Files.Model.Command_Palette.Move_Selection (Model, 1); end Palette_Move;
      procedure Palette_Close is begin Files.Model.Command_Palette.Close (Model); end Palette_Close;
      procedure Path_Focus is begin Files.Model.Focus_Path_Input (Model); end Path_Focus;
      procedure Path_Type is begin Files.Model.Set_Path_Input_Text (Model, "/probe/elsewhere"); end Path_Type;
      procedure Path_Caret is begin Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left); end Path_Caret;
      procedure Path_Leave is begin Files.Model.Cancel_Focus_Or_Edit (Model); end Path_Leave;
      procedure Type_Ahead is
         Matched : Boolean;
      begin
         Files.Model.Selection.Type_Ahead_Input (Model, "item", Matched);
         Assert (Matched, "type-ahead finds an item");
      end Type_Ahead;
      procedure Group is begin Settings.Group_By := Files.Preference_Types.Group_By_Label; end Group;
      procedure Ungroup is begin Settings.Group_By := Files.Preference_Types.No_Grouping; end Ungroup;
      procedure Scroll_Down is begin Files.Model.Set_Main_View_Scroll_Lines (Model, 10); end Scroll_Down;
      procedure Scroll_Up is begin Files.Model.Set_Main_View_Scroll_Lines (Model, 0); end Scroll_Up;
      procedure Pick is begin Files.Model.Selection.Select_Visible (Model, 3); end Pick;
      procedure Pick_Other is begin Files.Model.Selection.Toggle_Visible_Selection (Model, 7); end Pick_Other;
      procedure Filter is begin Files.Model.Filtering.Set_Filter (Model, "1"); end Filter;
      procedure Unfilter is begin Files.Model.Filtering.Clear_Filter (Model); end Unfilter;
      procedure Resort is begin Files.Model.Select_Sort_Field (Model, Files.Types.Sort_Size); end Resort;
      --  Settings the rows do not show (the space bar, a column's width),
      --  and ones they do (extensions, a label): the slots must follow both.
      procedure Space_Bar is begin Settings.Show_Space_Bar := not Settings.Show_Space_Bar; end Space_Bar;
      procedure Widen is
      begin
         Settings.Column_Widths (Files.Preference_Types.Size_Column) := Settings.Column_Widths
           (Files.Preference_Types.Size_Column) + 7;
      end Widen;
      procedure Extensions is
      begin
         Settings.Show_File_Extensions := not Settings.Show_File_Extensions;
      end Extensions;
      procedure Label is
      begin
         Files.Settings.Path_References.Set_Label
           (Settings, To_String (Files.Model.Visible_Item (Model, 2).Full_Path), Files.Preference_Types.Green);
      end Label;
   begin
      for I in 1 .. 60 loop
         Items.Append
           (Files.File_System.Make_Item (Files_Suite.Support.Disk.Root, "item" & I'Image, Files.Types.Regular_File_Item,
                                         "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Files_Suite.Support.Disk.Root, Items, Files_Suite.Support.Disk.Root);
      Files.Model.Set_View_Mode (Model, Files.Preference_Types.Details);
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
            Header_Step (Mode & "palette opened", Palette_Open'Access, Draw);
            Header_Step (Mode & "palette query typed", Palette_Type'Access, Draw);
            Header_Step (Mode & "palette highlight moved", Palette_Move'Access, Draw);
            Header_Step (Mode & "palette closed", Palette_Close'Access, Draw);
            Header_Step (Mode & "path field focused", Path_Focus'Access, Draw);
            Header_Step (Mode & "path field typed in", Path_Type'Access, Draw);
            Header_Step (Mode & "path caret moved", Path_Caret'Access, Draw);
            Step (Mode & "path field left", Path_Leave'Access, Draw);
            Header_Step (Mode & "type-ahead", Type_Ahead'Access, Draw);
            Step (Mode & "grouped by label", Group'Access, Draw);
            Assert (Natural (View.Snapshots (View.Current_Slot).Items.Length) > Files.Model.Visible_Count (Model),
                    Mode & "grouped: the rows hold headers");
            Check_Rows (Mode & "grouped");
            Step (Mode & "selected while grouped", Pick'Access, Draw);
            Header_Step (Mode & "palette opened while grouped", Palette_Open'Access, Draw);
            Header_Step (Mode & "palette closed while grouped", Palette_Close'Access, Draw);
            Step (Mode & "another selection while grouped", Pick_Other'Access, Draw);
            Step (Mode & "ungrouped", Ungroup'Access, Draw);
            Check_Rows (Mode & "ungrouped");
         end;
      end loop;
   end Test_Snapshot_Slots_Track_The_Model;
