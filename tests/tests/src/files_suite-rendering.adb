with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with AUnit.Test_Suites;

with System;

with Files.Events;
with Files.Fonts;
with Files.Rendering;
with Files.Rendering.Vulkan;
with Files.Types;

--  Rendering tests expressed as layout INVARIANTS and behaviours rather than
--  exact pixel coordinates. Each routine constructs its own deterministic view
--  snapshot, so there is no shared mutable state between tests, and the
--  assertions survive intentional visual-design changes (margins, insets, row
--  strides, scrollbar widths) while still catching genuine layout regressions.
package body Files_Suite.Rendering is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Files.Rendering;
   use type Files.Rendering.Render_Color;
   use type Files.Rendering.Settings_Hit_Kind;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Events.Input_Action_Kind;
   use type System.Address;

   type Rendering_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Rendering_Test_Case);

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Main_View_Scroll_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Frame_Rendering_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extreme_Size_Saturation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Hit_Testing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Scroll_Clamp (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files rendering and events");
   end Name;

   overriding procedure Register_Tests (T : in out Rendering_Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Layout_Invariants'Access, "item layout invariants across view modes");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Main_View_Scroll_Invariants'Access, "main-view scroll and scrollbar invariants");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Command_Palette_Invariants'Access, "command-palette layout invariants");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Frame_Rendering_Invariants'Access, "frame rendering invariants");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extreme_Size_Saturation'Access, "layout saturates at extreme sizes without overflow");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Click_Translation_Behavior'Access, "click translation behaviour");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Hit_Testing'Access, "settings-pane click hit-testing");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Glyph_Rasterization'Access, "frame text rasterizes through textrender");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Vulkan_Submission'Access, "frame builds a vulkan submission batch");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Settings_Scroll_Clamp'Access, "settings pane clamps over-scroll to its content");
   end Register_Tests;

   --  Build a deterministic snapshot with Count regular-file items in Mode.
   function Sample_Snapshot
     (Count : Natural;
      Mode  : Files.Types.View_Mode)
      return View_Snapshot
   is
      Snapshot : View_Snapshot;
   begin
      Snapshot.View_Mode := Mode;
      for Index in 1 .. Count loop
         Snapshot.Items.Append
           (Item_Snapshot'
              (Name          => To_Unbounded_String ("item" & Integer'Image (Index)),
               Filetype      => To_Unbounded_String ("text/plain"),
               Kind          => Files.Types.Regular_File_Item,
               Visible_Index => Index,
               others        => <>));
      end loop;
      Snapshot.Item_Count    := Count;
      Snapshot.Visible_Count := Count;
      return Snapshot;
   end Sample_Snapshot;

   --  True when the frame contains at least one filled rectangle of Color.
   function Has_Rectangle_Colored
     (Frame : Frame_Commands;
      Color : Render_Color)
      return Boolean is
   begin
      for Rect of Frame.Rectangles loop
         if Rect.Color = Color then
            return True;
         end if;
      end loop;
      return False;
   end Has_Rectangle_Colored;

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Types.View_Mode :=
        (Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details);
   begin
      for Mode of Modes loop
         declare
            Snapshot : constant View_Snapshot := Sample_Snapshot (6, Mode);
            Layout   : constant Layout_Metrics :=
              Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
            Items    : constant Item_Layout_Vectors.Vector :=
              Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);
         begin
            Assert (Natural (Items.Length) = 6, "every visible item is laid out");
            for Cell of Items loop
               Assert (Cell.Width > 0 and then Cell.Height > 0, "item cell has a positive size");
               Assert
                 (Cell.X >= Layout.Main_X
                  and then Cell.X + Cell.Width <= Layout.Main_X + Layout.Main_Width,
                  "item cell stays within the main-view width");
               Assert (Cell.Y >= Layout.Main_Y, "item cell starts at or below the main-view top");
            end loop;
            for Index in Items.First_Index .. Items.Last_Index - 1 loop
               declare
                  This_Cell : constant Item_Layout := Items.Element (Index);
                  Next_Cell : constant Item_Layout := Items.Element (Index + 1);
               begin
                  Assert
                    (Next_Cell.X >= This_Cell.X + This_Cell.Width
                     or else Next_Cell.Y >= This_Cell.Y + This_Cell.Height,
                     "consecutive items advance right or down without overlapping");
               end;
            end loop;
            declare
               First : constant Item_Layout := Items.Element (Items.First_Index);
            begin
               Assert
                 (Item_At (Items, First.X + First.Width / 2, First.Y + First.Height / 2)
                  = First.Visible_Index,
                  "a hit test inside a cell returns that item");
            end;
         end;
      end loop;
   end Test_Item_Layout_Invariants;

   procedure Test_Main_View_Scroll_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Few    : constant View_Snapshot := Sample_Snapshot (2, Files.Types.Details);
      Few_L  : constant Layout_Metrics := Calculate_Layout (Few, 1000, 800, 20);
      Few_MV : constant Main_View_Layout := Calculate_Main_View_Layout (Few, Few_L, 20);
   begin
      Assert (not Few_MV.Scrollbar_Visible, "no scrollbar is shown when content fits the viewport");

      declare
         Many   : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         Layout : constant Layout_Metrics := Calculate_Layout (Many, 400, 160, 20);
         MV     : constant Main_View_Layout := Calculate_Main_View_Layout (Many, Layout, 20);
      begin
         Assert (MV.Scrollbar_Visible, "a scrollbar appears when content overflows the viewport");
         Assert (MV.Content_Height > Layout.Main_Height, "overflow content exceeds the viewport");
         Assert
           (MV.Scrollbar_X >= Layout.Main_X
            and then MV.Scrollbar_X + MV.Scrollbar_Width <= Layout.Main_X + Layout.Main_Width,
            "the scrollbar stays within the main view horizontally");
         Assert
           (MV.Scrollbar_Track_Height > 0
            and then MV.Scrollbar_Track_Height <= Layout.Main_Height,
            "the scrollbar track fits within the viewport");
         Assert
           (MV.Scrollbar_Thumb_Y >= MV.Scrollbar_Y
            and then MV.Scrollbar_Thumb_Y <= MV.Scrollbar_Y + MV.Scrollbar_Track_Height,
            "the scrollbar thumb stays inside its track");
         Assert
           (MV.Scrollbar_Height > 0 and then MV.Scrollbar_Height <= MV.Scrollbar_Track_Height,
            "the thumb is no taller than its track");
      end;

      declare
         Top    : View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         Bottom : View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
      begin
         Top.Main_View_Scroll_Lines    := 0;
         Bottom.Main_View_Scroll_Lines := 1000;
         declare
            Layout : constant Layout_Metrics := Calculate_Layout (Top, 400, 160, 20);
            MV_Top : constant Main_View_Layout := Calculate_Main_View_Layout (Top, Layout, 20);
            MV_Bot : constant Main_View_Layout := Calculate_Main_View_Layout (Bottom, Layout, 20);
         begin
            Assert (MV_Bot.Scroll_Pixels >= MV_Top.Scroll_Pixels, "scrolling further never scrolls less");
            Assert (MV_Bot.Scroll_Pixels <= MV_Bot.Content_Height, "the scroll offset is bounded by content");
         end;
      end;

      --  Regression: the last row must be reachable (laid out with non-zero
      --  height) at maximum scroll. Row-period snapping must not floor the
      --  offset below the point that brings the final, partially-fitting row
      --  fully into view, in any view mode.
      for Mode in Files.Types.View_Mode loop
         declare
            Full  : View_Snapshot := Sample_Snapshot (60, Mode);
            L     : constant Layout_Metrics := Calculate_Layout (Full, 400, 300, 20);
            Cells : Item_Layout_Vectors.Vector;
         begin
            Full.Main_View_Scroll_Lines := 100_000;
            Cells := Calculate_Item_Layout (Full, L, Line_Height => 20);
            Assert (not Cells.Is_Empty, "item layout produced at maximum scroll");
            Assert
              (Cells.Element (Cells.Last_Index).Height > 0,
               "the last row is reachable at maximum scroll (" & Mode'Image & ")");
         end;
      end loop;
   end Test_Main_View_Scroll_Invariants;

   procedure Test_Command_Palette_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      Layout   : constant Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Palette  : constant Command_Palette_Layout := Calculate_Command_Palette_Layout (Layout, 20);
   begin
      Assert (Palette.Width > 0 and then Palette.Height > 0, "the palette has a positive size");
      Assert (Palette.X + Palette.Width <= Layout.Width, "the palette fits within the window width");
      Assert (Palette.Y + Palette.Height <= Layout.Height, "the palette fits within the window height");
      Assert (Palette.Search_Y >= Palette.Y, "the search field is inside the palette");
      Assert (Palette.Results_Y >= Palette.Search_Y, "results are placed below the search field");
      Assert
        (Palette.Search_X >= Palette.X
         and then Palette.Search_X + Palette.Search_Width <= Palette.X + Palette.Width,
         "the search field stays within the palette width");
   end Test_Command_Palette_Invariants;

   procedure Test_Frame_Rendering_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Selected : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      Invalid  : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);
   begin
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Selected, 1000, 800, 20);
      begin
         Assert (Natural (Frame.Rectangles.Length) > 0, "a frame emits rectangle draw commands");
      end;

      declare
         Item : Item_Snapshot := Selected.Items.Element (2);
      begin
         Item.Selected := True;
         Selected.Items.Replace_Element (2, Item);
      end;
      Selected.Selected_Count := 1;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Selected, 1000, 800, 20);
      begin
         Assert
           (Has_Rectangle_Colored (Frame, Selection_Color),
            "a selected item renders a selection rectangle");
      end;

      Invalid.Path_Input_Valid := False;
      Invalid.Focus            := Files.Types.Focus_Path_Input;
      Invalid.Path_Input_Text  := To_Unbounded_String ("/does/not/exist");
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Invalid, 1000, 800, 20);
      begin
         Assert
           (Has_Rectangle_Colored (Frame, Input_Error_Color),
            "a focused invalid path input renders an error indicator");
      end;
   end Test_Frame_Rendering_Invariants;

   procedure Test_Extreme_Size_Saturation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (8, Files.Types.Details);
      Layout   : Layout_Metrics;
      Items    : Item_Layout_Vectors.Vector;
      Main     : Main_View_Layout;
   begin
      Snapshot.Info_Pane_Open := True;
      Snapshot.Selected_Info.Append (Info_Snapshot'(others => <>));
      Snapshot.Main_View_Scroll_Lines := Natural'Last;

      --  None of these may raise CONSTRAINT_ERROR at extreme sizes; reaching
      --  the assertions proves the layout saturates instead of overflowing.
      Layout := Calculate_Layout
        (Snapshot, Width => Natural'Last, Height => Natural'Last, Line_Height => Positive'Last);
      Items  := Calculate_Item_Layout (Snapshot, Layout, Line_Height => Positive'Last);
      Main   := Calculate_Main_View_Layout (Snapshot, Layout, Line_Height => Positive'Last);

      declare
         Info  : constant Info_Pane_Layout :=
           Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => Positive'Last);
         Frame : constant Frame_Commands :=
           Build_Frame_Commands
             (Snapshot, Width => Natural'Last, Height => Natural'Last, Line_Height => Positive'Last);
      begin
         Assert (Natural (Items.Length) = 8, "items are still laid out at extreme sizes");
         Assert (Layout.Toolbar_Height = Natural'Last, "a huge line height saturates the toolbar height");
         Assert (Main.Content_Height = Natural'Last, "huge content height saturates instead of overflowing");
         Assert (Main.Scroll_Pixels <= Main.Content_Height, "the saturated scroll offset stays bounded");
         Assert (Info.Scroll_Pixels <= Info.Content_Height, "the info-pane scroll offset stays bounded");
         Assert (Frame.Layout.Toolbar_Height = Natural'Last, "the rendered frame layout also saturates");
      end;
   end Test_Extreme_Size_Saturation;

   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout   : constant Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Items    : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      First    : constant Item_Layout := Items.Element (Items.First_Index);
      On_Item  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame,
           X      => First.X + First.Width / 2,
           Y      => First.Y + First.Height / 2,
           Width  => 1000,
           Height => 800);
      Off_Item : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X => 995, Y => 700, Width => 1000, Height => 800);
   begin
      Assert
        (On_Item.Kind /= Files.Events.No_Input_Action,
         "clicking an item produces an input action");
      Assert
        (Off_Item.Kind = Files.Events.No_Input_Action,
         "clicking empty space below the content produces no action");
   end Test_Click_Translation_Behavior;

   procedure Test_Settings_Hit_Testing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame : Frame_Commands;
   begin
      --  A full-width field row, a more-specific inline option segment appended
      --  after it (reverse precedence must prefer the segment), and a reset
      --  button. These mirror how Build_Frame_Commands layers settings hits.
      Frame.Settings_Hits.Append
        (Settings_Hit_Region'
           (Kind => Settings_Hit_Field, Field => 1, Option => 0,
            X => 100, Y => 100, Width => 300, Height => 40));
      Frame.Settings_Hits.Append
        (Settings_Hit_Region'
           (Kind => Settings_Hit_Segment, Field => 1, Option => 2,
            X => 320, Y => 100, Width => 60, Height => 40));
      Frame.Settings_Hits.Append
        (Settings_Hit_Region'
           (Kind => Settings_Hit_Reset, Field => 0, Option => 0,
            X => 100, Y => 160, Width => 120, Height => 30));

      Assert
        (Settings_Hit_At (Frame, 110, 110).Kind = Settings_Hit_Field
         and then Settings_Hit_At (Frame, 110, 110).Field = 1,
         "a click on a settings field row resolves to that field");
      Assert
        (Settings_Hit_At (Frame, 340, 110).Kind = Settings_Hit_Segment
         and then Settings_Hit_At (Frame, 340, 110).Option = 2,
         "a click on an inline option segment resolves to the segment, not the row beneath it");
      Assert
        (Settings_Hit_At (Frame, 150, 170).Kind = Settings_Hit_Reset,
         "a click on the reset region resolves to reset");
      Assert
        (Settings_Hit_At (Frame, 5, 5).Kind = Settings_Hit_None,
         "a click outside every settings region resolves to none");
   end Test_Settings_Hit_Testing;

   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Result   : Text_Render_Result;
   begin
      Assert (Files.Fonts.Default_Font_Path /= "", "a default text font is available");
      Assert
        (Initialize_Text
           (Renderer    => Renderer,
            Font_Path   => Files.Fonts.Default_Font_Path,
            Pixel_Size  => 16,
            Cell_Width  => 10,
            Cell_Height => 20) = Text_Render_Success,
         "the text renderer loads the default font");
      Result := Build_Text_Glyphs (Renderer, Frame);
      Assert (Result.Status = Text_Render_Success, "frame text rasterizes through textrender");
      Assert (Natural (Result.Glyphs.Length) > 0, "the text renderer emits glyph draw commands");
      Assert (Result.Atlas_Pixels /= System.Null_Address, "the text renderer exposes an atlas");
   end Test_Text_Glyph_Rasterization;

   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Text     : Text_Render_Result;
      Batch    : Files.Rendering.Vulkan.Submission_Batch;
   begin
      Assert
        (Initialize_Text (Renderer, Files.Fonts.Default_Font_Path, 16, 10, 20) = Text_Render_Success,
         "the text renderer initialises for submission");
      Text  := Build_Text_Glyphs (Renderer, Frame);
      Batch := Files.Rendering.Vulkan.Build_Submission (Frame, Text);
      Assert (Batch.Width = Frame.Layout.Width, "the vulkan batch preserves the frame width");
      Assert (Batch.Height = Frame.Layout.Height, "the vulkan batch preserves the frame height");
      Assert
        (Batch.Rectangle_Vertex_Count = Natural (Frame.Rectangles.Length) * 6,
         "each rectangle expands to two triangles (six vertices)");
      Assert (Batch.Glyph_Vertex_Count > 0, "rasterized glyphs reach the vulkan submission batch");
   end Test_Vulkan_Submission;

   procedure Test_Settings_Scroll_Clamp (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot;
      Frame    : Frame_Commands;
   begin
      Snapshot.Settings_Pane_Open := True;
      --  Request a wildly out-of-range scroll. The renderer measures the
      --  settings content and clamps the offset, so content must remain on
      --  screen (hit regions are only emitted for visible rows) rather than
      --  scrolling off into blank space.
      Snapshot.Settings_Pane_Scroll_Lines := 100_000;
      Frame := Build_Frame_Commands (Snapshot, Width => 480, Height => 240, Line_Height => 20);
      Assert
        (Natural (Frame.Settings_Hits.Length) > 0,
         "settings content stays reachable after an extreme scroll (scroll is clamped)");
   end Test_Settings_Scroll_Clamp;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Rendering_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Rendering;
