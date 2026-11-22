with Hostkit.Fs;
with Files.Settings.Path_References.Testing;
with Files.UI_Types;
with Files.File_System_Types;
with Files.Model.Status_Samples;
with Ada.Containers.Ordered_Maps;
with Files.Folder_Size;
with Files.Model.Folder_Sizes;
with Files.Model.Info_Pane;
with Files.Model.Clipboard;
with Files.Item_Lists;
with Files.Text_Case.Testing;
with Files.Model.Filtering;
with Files.Model.Rename;
with Guikit.Item_Grid;
with Ada.Real_Time;
with Ada.Text_IO;
with Files.Controller;
with Files.Interaction;
with Files.Overlays;
with Files.Overlays.Testing;
with Files.Preference_Types;
with Files.Settings;
with Guikit.Input;
with Files_Suite.Support.Models;
with Ada.Calendar;
with Files.Application.Snapshot_Slots;
with Files.Model.Command_Palette;
with Files.Rendering.Testing;
with Files.Text_Case;
with Files.Settings.Path_References;
with Files.Overlays.Settings_Form;
with Files.Model.Settings_Pane;
with A11ykit;
with A11ykit.Tree;
separate (Files_Suite.Rendering)
   --  In a large folder, the work a pointer move, a hover over the settings
   --  pane, a marquee move and a type-ahead keystroke do is bounded by what
   --  is on screen or selected, not by the folder's size. Each prints its
   --  timing for the record.
   procedure Test_Large_Folder_Work_Stays_On_Screen
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      Count  : constant := 20_000;
      Width  : constant Natural  := 1000;
      Height : constant Natural := 800;
      LH     : constant Positive := 20;

      function Per_Round (Start : Ada.Real_Time.Time; Rounds : Positive) return String is
        (Duration'Image (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start) / Rounds * 1000) & " ms");
   begin
      --  A pointer frame over a 20k-item Details view.
      declare
         Snap   : constant View_Snapshot := Sample_Snapshot (Count, Files.Preference_Types.Details);
         Texts  : Row_Text_Cache;
         Rounds : constant := 50;
         Start  : Ada.Real_Time.Time;
      begin
         declare
            F : constant Frame_Commands :=
              Build_Frame_Commands
                (Snap, 1, Texts, Width, Height, LH, (Hover_X => 200, Hover_Y => 100, Has_Hover => True, others => <>));
            pragma Unreferenced (F);
         begin
            null;
         end;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               F : constant Frame_Commands :=
                 Build_Frame_Commands
                   (Snap, 1, Texts, Width, Height, LH,
                    (Hover_X => 200, Hover_Y => 100 + Round mod 300, Has_Hover => True, others => <>));
               pragma Unreferenced (F);
            begin
               null;
            end;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: pointer frame, 20k Details rows" & Per_Round (Start, Rounds));
         declare
            Layout : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Layouts.Calculate_Layout (Snap, Width, Height, LH);
            Placed : constant Files.Rendering.Layouts.Placed_Item_Layout :=
              Files.Rendering.Layouts.Place_Item_Layout (Snap, Layout, LH);
            Full   : constant Files.Rendering.Layouts.Item_Layout_Vectors.Vector :=
              Files.Rendering.Layouts.Calculate_Item_Layout (Snap, Layout, LH);
            Drawn  : Natural := 0;
         begin
            Assert (not Placed.Cells.Is_Empty, "the rows on screen are placed");
            Assert (Natural (Placed.Cells.Length) <= Height / LH, "only the rows on screen are placed");
            for Position in 1 .. Count loop
               if Full (Position).Height > 0 then
                  Drawn := Drawn + 1;
                  Assert
                    (Guikit.Item_Grid."=" (Full (Position), Files.Rendering.Layouts.Cell_At (Placed, Position)),
                     "a placed cell is the cell the whole layout has there");
               end if;
            end loop;
            Assert (Drawn = Natural (Placed.Cells.Length), "every cell with an area is placed, and no other");
         end;
      end;

      --  A hover move over the open settings pane.
      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
         Rects    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
         Text     : Guikit.Draw.Text_Command_Vectors.Vector;
         Nodes    : Guikit.Draw.Accessibility_Node_Vectors.Vector;
         Rounds   : constant := 200;
         Start    : Ada.Real_Time.Time;
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => "",
            Key => Guikit.Input.Key_Comma, Modifiers => [Guikit.Input.Control_Key => True, others => False],
            Result => Result);
         declare
            Fields      : Files.Overlays.Settings_Fields_Cache;
            Kept_Rects  : Guikit.Draw.Rectangle_Command_Vectors.Vector;
            Kept_Text   : Guikit.Draw.Text_Command_Vectors.Vector;
            Kept_Nodes  : Guikit.Draw.Accessibility_Node_Vectors.Vector;
            Fresh       : Duration;
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Files.Overlays.Build_Settings_Frame
                 (Model => Model,
                  Region => (X => 0, Y => 0, Width => 600, Height => 500,
                             Clip_Width => 600, Clip_Height => 500, Line_Height => LH),
                  Focused => True, Hover_X => 100 + Round mod 300, Hover_Y => 200,
                  Rectangles => Rects, Text => Text, Accessibility => Nodes);
            end loop;
            Fresh := Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Files.Overlays.Build_Settings_Frame
                 (Model => Model,
                  Region => (X => 0, Y => 0, Width => 600, Height => 500,
                             Clip_Width => 600, Clip_Height => 500, Line_Height => LH),
                  Focused => True, Hover_X => 100 + Round mod 300, Hover_Y => 200, Fields => Fields,
                  Rectangles => Kept_Rects, Text => Kept_Text, Accessibility => Kept_Nodes);
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: settings pane hover" & Per_Round (Start, Rounds) & " kept fields vs"
               & Duration'Image (Fresh / Rounds * 1000) & " ms rebuilt");
            Assert (Files.Overlays.Testing.Builds (Fields) = 1, "a hover move over the settings pane keeps its fields");
            Assert
              (Guikit.Draw.Text_Command_Vectors."=" (Kept_Text, Text)
               and then Guikit.Draw.Rectangle_Command_Vectors."=" (Kept_Rects, Rects),
               "a frame from kept fields draws what a rebuilt one draws");
            --  A settings change builds them again.
            Files.Model.Note_Settings_Changed (Model);
            Files.Overlays.Build_Settings_Frame
              (Model => Model,
               Region => (X => 0, Y => 0, Width => 600, Height => 500,
                          Clip_Width => 600, Clip_Height => 500, Line_Height => LH),
               Focused => True, Hover_X => -1, Hover_Y => -1, Fields => Fields,
               Rectangles => Kept_Rects, Text => Kept_Text, Accessibility => Kept_Nodes);
            Assert (Files.Overlays.Testing.Builds (Fields) = 2, "a settings change builds the fields again");
         end;
      end;

      --  A marquee move adding to a 5k-item selection, and a type-ahead
      --  keystroke, in a 20k-item folder.
      declare
         Items : Files.Items.Item_Vectors.Vector;
         Model : Files.Model.Window_Model;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.Item_Lists.Make_Item
                 ("/probe", "item" & Integer'Image (Index), Files.Types.Regular_File_Item, "text/plain"));
         end loop;
         Files.Model.Initialize
           (Model,
            Directory_Path    => "/probe",
            Items             => Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Preference_Types.Details);
         declare
            Base_List : Files.Model.Selection.Visible_Index_List;
            Hits      : Files.Interaction.Marquee_Rows;
            Rounds    : constant := 50;
            Start     : Ada.Real_Time.Time;
         begin
            for Index in 1 .. 5_000 loop
               Base_List.Append (Index * 4);
            end loop;
            Files.Model.Selection.Select_Visible_Set (Model, Base_List);
            declare
               Base : constant Files.Types.String_Vectors.Vector := Files.Interaction.Marquee_Base (Model);
            begin
               Start := Ada.Real_Time.Clock;
               for Round in 1 .. Rounds loop
                  Hits.Clear;
                  for Row in 1 .. 10 + Round mod 5 loop
                     Hits.Append (Row);
                  end loop;
                  Files.Interaction.Apply_Marquee_Selection (Model, Hits, Additive => True, Base => Base);
               end loop;
               Ada.Text_IO.Put_Line
                 ("large-folder: additive marquee move, base rows found per move" & Per_Round (Start, Rounds));
               declare
                  Key       : constant Natural := Files.Model.Selection.Visible_Rows_Key (Model);
                  Base_Rows : constant Files.Interaction.Marquee_Rows :=
                    Files.Interaction.Marquee_Base_Rows (Model, Base);
               begin
                  Start := Ada.Real_Time.Clock;
                  for Round in 1 .. Rounds loop
                     Hits.Clear;
                     for Row in 1 .. 10 + Round mod 5 loop
                        Hits.Append (Row);
                     end loop;
                     Files.Interaction.Apply_Marquee_Selection (Model, Hits, Additive => True, Base_Rows => Base_Rows);
                  end loop;
                  Ada.Text_IO.Put_Line
                    ("large-folder: additive marquee move, base rows kept" & Per_Round (Start, Rounds));
                  Assert
                    (Files.Model.Selection.Visible_Rows_Key (Model) = Key,
                     "selecting does not move the visible rows, so the base's rows stand");
               end;
               Assert
                 (Natural (Files.Model.Selection.Selected_Paths (Model).Length) = 5_000 + 10 - 2,
                  "the marquee keeps the base and adds its hits");
            end;
         end;
         declare
            Rounds : constant := 50;
            Start  : Ada.Real_Time.Time := Ada.Real_Time.Clock;
            Result : Files.Controller.Controller_Result;
            pragma Unreferenced (Result);
         begin
            for Round in 1 .. Rounds loop
               Result := Files.Controller.Append_Focused_Text (Model, "z");
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: type-ahead keystroke, no match" & Per_Round (Start, Rounds));
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Result := Files.Controller.Append_Focused_Text (Model, "i");
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: type-ahead keystroke, cycling" & Per_Round (Start, Rounds));
            Assert
              (Files.Model.Selection.Selected_Index (Model) /= 0,
               "typing a letter the names start with selects one of them");
         end;
      end;

      --  A keystroke as the window sees it: the model change and the snapshot
      --  refresh after it, in a 20k-item Details folder. A palette or
      --  type-ahead keystroke leaves the rows, so its refresh keeps them; the
      --  full rebuild it once forced is timed beside it.
      declare
         Items    : Files.Items.Item_Vectors.Vector;
         Model    : Files.Model.Window_Model;
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         View     : Files.Application.Snapshot_Slots.View_Slots;
         Wall     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Rounds   : constant := 20;
         Start    : Ada.Real_Time.Time;

         procedure Refresh is
         begin
            Files.Model.Sync_Grouping (Model, Settings);
            Files.Application.Snapshot_Slots.Refresh (View, Model, Settings, Ada.Real_Time.Clock, Wall);
            View.Drawn_Slot := View.Current_Slot;
         end Refresh;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.Item_Lists.Make_Item
                 ("/probe", "item" & Integer'Image (Index), Files.Types.Regular_File_Item, "text/plain"));
         end loop;
         Files.Model.Initialize
           (Model, Directory_Path => "/probe", Items => Items, Home_Path => "/home/test",
            Default_View_Mode => Files.Preference_Types.Details);
         Refresh;

         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               Snap : constant View_Snapshot := Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Wall);
               pragma Unreferenced (Snap);
            begin
               null;
            end;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: full snapshot rebuild (what a row change costs)" & Per_Round (Start, Rounds));

         Files.Model.Command_Palette.Open (Model);
         Refresh;
         declare
            Rows : constant Natural := Files.Model.Rows_Revision (Model);
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Files.Model.Command_Palette.Set_Query (Model, (if Round mod 2 = 0 then "co" else "c"));
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: palette keystroke and refresh" & Per_Round (Start, Rounds));
            Assert (Files.Model.Rows_Revision (Model) = Rows, "a palette keystroke leaves the rows");
         end;
         Files.Model.Command_Palette.Close (Model);
         Refresh;

         declare
            Rows   : constant Natural := Files.Model.Rows_Revision (Model);
            Result : Files.Controller.Controller_Result;
            pragma Unreferenced (Result);
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Result := Files.Controller.Append_Focused_Text (Model, "i");
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: type-ahead keystroke and refresh" & Per_Round (Start, Rounds));
            Assert (Files.Model.Rows_Revision (Model) = Rows, "a type-ahead keystroke leaves the rows");
         end;

         --  Shift+Down from an anchor: the anchor's row is found without a
         --  search of the items; the search it once was is timed beside it.
         Files.Model.Selection.Select_Visible (Model, 15_000);
         Refresh;
         declare
            Anchor_Path : constant String := To_String (Files.Model.Visible_Item (Model, 15_000).Full_Path);
            Found       : Natural := 0;
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               declare
                  Anchor : constant Natural := Files.Model.Selection.Range_Anchor (Model);
               begin
                  Files.Model.Selection.Select_Visible_Range (Model, Positive (Anchor), 15_000 + Round);
               end;
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: shift+down and refresh" & Per_Round (Start, Rounds));
            Assert (Files.Model.Selection.Range_Anchor (Model) = 15_000, "the range keeps its anchor");
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Found := Files.Model.Visible_Index_Of (Model, Anchor_Path);
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: anchor search by path (replaced)" & Per_Round (Start, Rounds));
            Assert (Found = 15_000, "the path search finds the anchor too");
         end;

         --  A filter keystroke changes which rows show, so it rebuilds them;
         --  the filter is folded once, not once per item.
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Filtering.Set_Filter (Model, (if Round mod 2 = 0 then "ITEM1" else "Item12"));
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: filter keystroke and refresh" & Per_Round (Start, Rounds));
         declare
            Matches : Natural := 0;
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               for Item of Items loop
                  if Files.Text_Case.Testing.Contains_Case_Insensitive (To_String (Item.Name), "Item12") then
                     Matches := Matches + 1;
                  end if;
               end loop;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: per-item filter folding (replaced)" & Per_Round (Start, Rounds));
            Assert (Matches = Rounds * Files.Model.Visible_Count (Model), "both matchers agree");
         end;

         --  Narrowing the filter with every item selected drops the hidden
         --  ones from the selection in one pass, not one at a time.
         declare
            Spent : Duration := 0.0;
         begin
            for Round in 1 .. Rounds loop
               Files.Model.Filtering.Set_Filter (Model, "");
               Files.Model.Selection.Select_All_Visible (Model);
               Start := Ada.Real_Time.Clock;
               Files.Model.Filtering.Set_Filter (Model, "item1");
               Spent := Spent + Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: filter narrowed after select all" & Duration'Image (Spent / Rounds * 1000) & " ms");
            Assert
              (Files.Model.Selection.Selected_Count (Model) = Files.Model.Visible_Count (Model),
               "the selection keeps exactly the items still shown");
         end;
         Files.Model.Filtering.Set_Filter (Model, "");
         Refresh;

         --  A header-only change with every item selected keeps the rows and
         --  the selection's total.
         Files.Model.Selection.Select_All_Visible (Model);
         Refresh;
         Files.Model.Command_Palette.Open (Model);
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Command_Palette.Set_Query (Model, (if Round mod 2 = 0 then "co" else "c"));
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: header-only refresh with all selected" & Per_Round (Start, Rounds));
         Files.Model.Command_Palette.Close (Model);
         Files.Model.Selection.Select_Visible (Model, 1);
         Refresh;

         --  A rename keystroke and caret move patch the renamed row only.
         Files.Model.Rename.Toggle (Model);
         Refresh;
         declare
            Rows   : constant Natural := Files.Model.Rows_Revision (Model);
            Typed  : Boolean;
            pragma Unreferenced (Typed);
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Typed := Files.Model.Rename.Insert_At_Carets (Model, "x");
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: rename keystroke and refresh" & Per_Round (Start, Rounds));
            Assert (Files.Model.Rows_Revision (Model) = Rows, "a rename keystroke leaves the other rows");
         end;
         Files.Model.Rename.Toggle (Model);
         Refresh;

         --  A plain left click on an item (nothing focused or edited) and a
         --  Ctrl+C leave the rows: only the selection and header move.
         declare
            Rows : constant Natural := Files.Model.Rows_Revision (Model);
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Files.Model.Cancel_Focus_Or_Edit (Model);
               Files.Model.Selection.Select_Visible (Model, 1 + Round mod 7);
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: left click on an item and refresh" & Per_Round (Start, Rounds));
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Files.Model.Clipboard.Set
                 (Model, Files.Model.Selection.Selected_Paths (Model), Files.Model.Clipboard_Copy);
               Refresh;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: Ctrl+C and refresh" & Per_Round (Start, Rounds));
            Assert (Files.Model.Rows_Revision (Model) = Rows, "a click and a copy leave the rows");
         end;

         --  Whether a header-only build draws as the one on screen: the two
         --  slots share the rows, which the window moves aside instead of
         --  comparing them row by row (Refresh_Cached_Frame).
         declare
            A : View_Snapshot := Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Wall);
            B : View_Snapshot := Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Wall);
            Same : Boolean := False;
         begin
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               Same := A = B;
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: snapshot compare, rows included (replaced)" & Per_Round (Start, Rounds));
            Start := Ada.Real_Time.Clock;
            for Round in 1 .. Rounds loop
               declare
                  A_Rows, B_Rows : Item_Snapshot_Vectors.Vector;
               begin
                  Item_Snapshot_Vectors.Move (A_Rows, A.Items);
                  Item_Snapshot_Vectors.Move (B_Rows, B.Items);
                  Same := A = B;
                  Item_Snapshot_Vectors.Move (A.Items, A_Rows);
                  Item_Snapshot_Vectors.Move (B.Items, B_Rows);
               end;
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: snapshot compare, shared rows moved aside" & Per_Round (Start, Rounds));
            Assert (Same and then Natural (A.Items.Length) = Count, "the rows come back after the compare");
         end;

         --  The info pane over a large selection, on a header-only change.
         Files.Model.Selection.Select_All_Visible (Model);
         Files.Model.Info_Pane.Toggle_Info_Pane (Model);
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Set_Error (Model, (if Round mod 2 = 0 then "error.probe" else ""));
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: header change with the info pane over 20k selected" & Per_Round (Start, Rounds));
         --  The pane's rows are kept by a header-only build: a mark put on
         --  them survives one, and goes with a change the pane shows (an
         --  account name sampled).
         declare
            Marked : Info_Snapshot := View.Snapshots (View.Current_Slot).Selected_Info.First_Element;
            First  : Info_Snapshot;
         begin
            Assert (Natural (View.Snapshots (View.Current_Slot).Selected_Info.Length) = Files.UI_Types.Max_Info_Items,
                    "the pane lists the first items of the selection");
            Marked.Name := To_Unbounded_String ("kept-mark");
            for Slot in View.Snapshots'Range loop
               if not View.Snapshots (Slot).Selected_Info.Is_Empty then
                  View.Snapshots (Slot).Selected_Info.Replace_Element (1, Marked);
               end if;
            end loop;
            Files.Model.Set_Error (Model, "error.probe.kept");
            Refresh;
            First := View.Snapshots (View.Current_Slot).Selected_Info.First_Element;
            Assert (To_String (First.Name) = "kept-mark", "a header-only build keeps the pane's rows");
            Files.Model.Status_Samples.Set_Account_Name
              (Model, Files.File_System_Types.User_Account, 4_242, "kept-probe");
            Refresh;
            First := View.Snapshots (View.Current_Slot).Selected_Info.First_Element;
            Assert (To_String (First.Name) /= "kept-mark", "an account name sampled rebuilds them");
            Files.Model.Set_Error (Model, "");
            Refresh;
         end;
         Files.Model.Info_Pane.Toggle_Info_Pane (Model);
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Set_Error (Model, (if Round mod 2 = 0 then "error.probe" else ""));
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: header change, info pane closed, 20k selected" & Per_Round (Start, Rounds));
         Files.Model.Selection.Select_Visible (Model, 1);
         Refresh;
      end;

      --  Folder sizes streaming in with 20k folders selected: each hand-over
      --  looks up the folders it measured and moves the kept total, where it
      --  mapped every selected folder and the snapshot summed them all again.
      declare
         Items    : Files.Items.Item_Vectors.Vector;
         Model    : Files.Model.Window_Model;
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         View     : Files.Application.Snapshot_Slots.View_Slots;
         Wall     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Rounds   : constant := 20;
         Start    : Ada.Real_Time.Time;
         Expected : Long_Long_Integer := 0;

         procedure Refresh is
         begin
            Files.Application.Snapshot_Slots.Refresh (View, Model, Settings, Ada.Real_Time.Clock, Wall);
            View.Drawn_Slot := View.Current_Slot;
         end Refresh;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.Item_Lists.Make_Item ("/probe", "folder" & Integer'Image (Index), Files.Types.Directory_Item));
         end loop;
         Files.Model.Initialize
           (Model, Directory_Path => "/probe", Items => Items, Home_Path => "/home/test",
            Default_View_Mode => Files.Preference_Types.Details);
         Files.Model.Selection.Select_All_Visible (Model);
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               Measured : Files.Folder_Size.Measurement_Vectors.Vector;
            begin
               for Folder in 1 .. 10 loop
                  Measured.Append
                    (Files.Folder_Size.Measurement'
                       (Path   => Items ((Round - 1) * 10 + Folder).Full_Path,
                        Result => (Available => True, Total_Bytes => 100, others => <>),
                        Listed => Files.Types.Unknown_Time));
                  Expected := Expected + 100;
               end loop;
               Files.Model.Folder_Sizes.Note (Model, Measured);
               Refresh;
            end;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: folder-size hand-over and refresh, 20k folders selected" & Per_Round (Start, Rounds));
         Files_Suite.Support.Assert_Equal
           (View.Snapshots (View.Current_Slot).Selection_Total_Bytes, Expected,
            "the kept total counts every folder measured");
         Assert (View.Snapshots (View.Current_Slot).Selection_Total_Pending, "with folders still unmeasured");
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               --  What each hand-over did before: map every selected folder.
               package Time_Maps is new Ada.Containers.Ordered_Maps
                 (Key_Type => Ada.Strings.Unbounded.Unbounded_String, Element_Type => Ada.Calendar.Time,
                  "<" => Ada.Strings.Unbounded."<", "=" => Ada.Calendar."=");
               Selected : Time_Maps.Map;
               procedure Add (Item : Files.Items.Directory_Item) is
               begin
                  Selected.Include (Item.Full_Path, Item.Modified_Time);
               end Add;
            begin
               Files.Model.Selection.For_Each_Selected_Item (Model, Add'Access);
            end;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: mapping every selected folder per hand-over (replaced)" & Per_Round (Start, Rounds));
      end;

      --  A filter keystroke over 20k names that are not ASCII: each name is
      --  folded once per listing, not once per keystroke.
      declare
         Upper_A : constant String := Character'Val (16#C3#) & Character'Val (16#84#);
         Lower_A : constant String := Character'Val (16#C3#) & Character'Val (16#A4#);
         Items   : Files.Items.Item_Vectors.Vector;
         Model   : Files.Model.Window_Model;
         Rounds  : constant := 20;
         Start   : Ada.Real_Time.Time;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.Item_Lists.Make_Item
                 ("/probe", Upper_A & "rger" & Integer'Image (Index), Files.Types.Regular_File_Item, "text/plain"));
         end loop;
         Files.Model.Initialize
           (Model, Directory_Path => "/probe", Items => Items, Home_Path => "/home/test",
            Default_View_Mode => Files.Preference_Types.Details);
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Filtering.Set_Filter
              (Model, (if Round mod 2 = 0 then Upper_A & "RGER 1" else Lower_A & "rger 12"));
            Assert (Files.Model.Visible_Count (Model) > 0, "folded names match the folded filter");
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: filter keystroke, non-ASCII names" & Per_Round (Start, Rounds));
         Files.Model.Filtering.Set_Filter (Model, Upper_A & "RGER 12");
         Assert (Files.Model.Visible_Count (Model) = 1_111, "the folded filter finds every name holding it");
      end;

      --  What a key or click pays to learn whether it changed the settings:
      --  a copy of them and a comparison, here with 500 labels.
      declare
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Rounds   : constant := 200;
         Start    : Ada.Real_Time.Time;
         Same     : Natural := 0;
      begin
         for Index in 1 .. 500 loop
            Files.Settings.Path_References.Testing.Set_Label
              (Settings, Hostkit.Fs.Join ("/probe", "item" & Integer'Image (Index)), Files.Preference_Types.Green);
         end loop;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            declare
               Before : constant Files.Settings.Settings_Model := Settings;
            begin
               if Files.Settings.Same_Content (Before, Settings) then
                  Same := Same + 1;
               end if;
            end;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: settings copy and compare per key, 500 labels" & Per_Round (Start, Rounds));
         Assert (Same = Rounds, "an unchanged copy compares equal");
      end;

      --  Settings changes no row shows, and labels, in a 20k-item folder:
      --  opening the settings pane and stepping in it leave the rows; a
      --  theme toggle keeps them; labelling every item patches each row's
      --  label where all the rows were built again. A rebuild is the cost
      --  each paid before.
      declare
         Items    : Files.Items.Item_Vectors.Vector;
         Model    : Files.Model.Window_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         View     : Files.Application.Snapshot_Slots.View_Slots;
         Wall     : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Rounds   : constant := 10;
         Start    : Ada.Real_Time.Time;
         Paths    : Files.Settings.String_Vectors.Vector;
         Rows     : Natural;

         procedure Refresh is
         begin
            Files.Application.Snapshot_Slots.Refresh (View, Model, Settings, Ada.Real_Time.Clock, Wall);
            View.Drawn_Slot := View.Current_Slot;
         end Refresh;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.Item_Lists.Make_Item
                 ("/probe", "item" & Integer'Image (Index), Files.Types.Regular_File_Item, "text/plain"));
            Paths.Append (To_Unbounded_String (Hostkit.Fs.Join ("/probe", "item" & Integer'Image (Index))));
         end loop;
         Files.Model.Initialize
           (Model, Directory_Path => "/probe", Items => Items, Home_Path => "/home/test",
            Default_View_Mode => Files.Preference_Types.Details);
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            View.Snapshot_Valid := False;
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: full rebuild (what each change below paid)" & Per_Round (Start, Rounds));

         Rows := Files.Model.Rows_Revision (Model);
         Start := Ada.Real_Time.Clock;
         Files.Overlays.Settings_Form.Begin_Edit (Model, Settings);
         Refresh;
         Ada.Text_IO.Put_Line ("large-folder: settings pane opened" & Per_Round (Start, 1));
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Model.Settings_Pane.Move_Focus (Model, 1);
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: settings pane step" & Per_Round (Start, Rounds));
         Files_Suite.Support.Assert_Equal
           (Files.Model.Rows_Revision (Model), Rows, "opening and stepping in the settings pane leaves the rows");
         Files.Model.Settings_Pane.Close (Model);

         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Settings.Theme :=
              (if Files.Settings."=" (Settings.Theme, Files.Settings.Theme_Dark)
               then Files.Settings.Theme_Light
               else Files.Settings.Theme_Dark);
            Settings.Show_File_Extensions := not Settings.Show_File_Extensions;
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: theme and extensions toggle" & Per_Round (Start, Rounds));

         declare
            Labelling : Duration := 0.0;
            Refreshing : Duration := 0.0;
         begin
            for Round in 1 .. Rounds loop
               Start := Ada.Real_Time.Clock;
               Files.Settings.Path_References.Set_Labels
                 (Settings, Paths,
                  (if Round mod 2 = 0 then Files.Preference_Types.Green else Files.Preference_Types.Red));
               Labelling := Labelling + Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
               Start := Ada.Real_Time.Clock;
               Refresh;
               Refreshing := Refreshing + Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Start);
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: label every item: labels set" & Duration'Image (Labelling / Rounds * 1000) & " ms,"
               & " rows patched" & Duration'Image (Refreshing / Rounds * 1000) & " ms");
         end;
         Assert
           (Files.Preference_Types."="
              (View.Snapshots (View.Current_Slot).Items (Count).Label, Files.Preference_Types.Green),
            "a labelled row shows its new label");
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            View.Snapshot_Valid := False;
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line
           ("large-folder: full rebuild with 20k labels (what a label change paid)" & Per_Round (Start, Rounds));
         Settings := Files.Settings.Default_Settings;
         Refresh;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Files.Settings.Path_References.Testing.Set_Label
              (Settings, Hostkit.Fs.Join ("/probe", "item" & Integer'Image (Round)),
               Files.Preference_Types.Blue);
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: label one item and refresh" & Per_Round (Start, Rounds));
         Assert
           (Files.Preference_Types."="
              (View.Snapshots (View.Current_Slot).Items (Rounds).Label, Files.Preference_Types.Blue),
            "the labelled row shows it");
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. 100 loop
            Refresh;
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: unchanged frame, 20k labels" & Per_Round (Start, 100));
      end;

      --  The accessibility tree of a 4K small-icon grid: its parents found
      --  by area order, where every node was tried as every node's parent.
      declare
         Flat   : A11ykit.Tree.Node_Vectors.Vector;
         Built  : A11ykit.Tree.Accessibility_Tree;
         Rounds : constant := 10;
         Start  : Ada.Real_Time.Time;
      begin
         Flat.Append (A11ykit.Tree.Node'(Bounds => (0, 0, 3840, 2160), others => <>));
         Flat.Append (A11ykit.Tree.Node'(Bounds => (0, 40, 3840, 2080), others => <>));
         for Row in 0 .. 29 loop
            for Column in 0 .. 49 loop
               Flat.Append (A11ykit.Tree.Node'(Bounds => (Column * 76, 40 + Row * 69, 72, 64), others => <>));
            end loop;
         end loop;
         Start := Ada.Real_Time.Clock;
         for Round in 1 .. Rounds loop
            Built := A11ykit.Tree.Build (Flat);
         end loop;
         Ada.Text_IO.Put_Line ("large-folder: accessibility tree of 1,502 nodes" & Per_Round (Start, Rounds));
         declare
            --  What Build did before: every node tried as every node's
            --  parent.
            Tried : Natural := 0;
         begin
            Start := Ada.Real_Time.Clock;
            for Child of Flat loop
               for Cand of Flat loop
                  if Cand.Bounds.X <= Child.Bounds.X and then Cand.Bounds.Y <= Child.Bounds.Y
                    and then Cand.Bounds.X + Cand.Bounds.Width >= Child.Bounds.X + Child.Bounds.Width
                    and then Cand.Bounds.Y + Cand.Bounds.Height >= Child.Bounds.Y + Child.Bounds.Height
                  then
                     Tried := Tried + 1;
                  end if;
               end loop;
            end loop;
            Ada.Text_IO.Put_Line
              ("large-folder: every node tried as every node's parent (replaced)" & Per_Round (Start, 1));
            Assert (Tried > 0, "containers found");
         end;
         Files_Suite.Support.Assert_Equal (Built.Nodes (2).Parent, 1, "the pane is in the window");
         Files_Suite.Support.Assert_Equal (Built.Nodes (1_502).Parent, 2, "a cell is in the pane");
      end;
   end Test_Large_Folder_Work_Stays_On_Screen;
