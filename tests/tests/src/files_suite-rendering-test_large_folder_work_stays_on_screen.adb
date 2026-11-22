with Files.Model.Filtering;
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
              (Files.File_System.Make_Item
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
            Hits      : Files.Model.Selection.Visible_Index_List;
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
                  Base_Rows : constant Files.Model.Selection.Visible_Index_List :=
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
              (Files.File_System.Make_Item
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
                  if Files.Text_Case.Contains_Case_Insensitive (To_String (Item.Name), "Item12") then
                     Matches := Matches + 1;
                  end if;
               end loop;
            end loop;
            Ada.Text_IO.Put_Line ("large-folder: per-item filter folding (replaced)" & Per_Round (Start, Rounds));
            Assert (Matches = Rounds * Files.Model.Visible_Count (Model), "both matchers agree");
         end;
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
            Files.Settings.Path_References.Set_Label
              (Settings, "/probe/item" & Integer'Image (Index), Files.Preference_Types.Green);
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
   end Test_Large_Folder_Work_Stays_On_Screen;
