with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;
with AUnit.Test_Suites;

with System;

with Files.Commands;
with Files.Events;
with Files.Fonts;
with Files.Localization;
with Files.Rendering;
with Files.Rendering.Vulkan;
with Files.Types;
with Files.UI;

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
   procedure Test_Large_Icons_Rename_Caret (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Hit_Testing (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Settings_Scroll_Clamp (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Panels_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Large_Icons_Rename_Caret'Access,
         "large-icons rename edits left-aligned across the cell with the caret in the label region");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret_Scales_With_Line_Height'Access, "the text-input caret height grows with the line height");
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Hidden_Count'Access, "bottom bar reflects the hidden count and exposes a toggle button");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Suppresses_Item_Hover'Access,
         "an open context menu suppresses the main-grid item hover highlight");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Panels_Expose_Close_Button'Access,
         "each open overlay panel emits a close-button accessibility node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Theme_Palette_Selection'Access,
         "the light palette differs from dark while high contrast keeps the dark base");
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
         --  Bug 16: the thumb length is proportional to the visible fraction,
         --  i.e. track_length * viewport_height / content_height with the
         --  viewport equal to the scroll track, clamped to a line-height
         --  minimum and to the track length. Derived purely from the layout's
         --  own exposed track/content, so a wrong denominator would break it.
         Assert
           (MV.Scrollbar_Height =
              Natural'Min
                (MV.Scrollbar_Track_Height,
                 Natural'Max
                   (20,
                    MV.Scrollbar_Track_Height * MV.Scrollbar_Track_Height / MV.Content_Height)),
            "the thumb length is the clamped proportional fraction of the track");
      end;

      --  Bug 16: with moderate overflow the thumb is comfortably above the
      --  minimum clamp, so proportionality must hold within integer rounding
      --  (thumb / track ~= track / content), and it must saturate: near-full
      --  content gives a near-full thumb, huge content gives the minimum.
      declare
         Mid    : constant View_Snapshot := Sample_Snapshot (26, Files.Types.Details);
         Layout : constant Layout_Metrics := Calculate_Layout (Mid, 900, 400, 20);
         MV     : constant Main_View_Layout := Calculate_Main_View_Layout (Mid, Layout, 20);
         Track  : constant Natural := MV.Scrollbar_Track_Height;
         Content : constant Natural := MV.Content_Height;
      begin
         Assert (MV.Scrollbar_Visible, "the moderately overflowing list shows a scrollbar");
         Assert (MV.Scrollbar_Height > 20, "moderate overflow keeps the thumb above the minimum clamp");
         --  |thumb * content - track * track| < content  <=>  thumb within 1px of track^2/content.
         Assert
           (MV.Scrollbar_Height * Content <= Track * Track + Content
            and then (MV.Scrollbar_Height + 1) * Content > Track * Track,
            "the thumb length equals track * viewport / content within rounding");
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

   --  Return the caret rectangle (a 1-2px wide Text_Color bar) emitted in Frame,
   --  or a zero rectangle if none. Found is set when a caret is present.
   procedure Find_Caret
     (Frame : Frame_Commands;
      X     : out Natural;
      Y     : out Natural;
      W     : out Natural;
      H     : out Natural;
      Found : out Boolean)
   is
   begin
      X := 0; Y := 0; W := 0; H := 0; Found := False;
      for Rect of Frame.Rectangles loop
         if Rect.Width in 1 .. 2 and then Rect.Color = Text_Color then
            X := Rect.X; Y := Rect.Y; W := Rect.Width; H := Rect.Height; Found := True;
         end if;
      end loop;
   end Find_Caret;

   --  Bug 13: in large-icons view the rename edit must span the cell width,
   --  left-aligned on the label line, with the caret contained in the cell's
   --  label region -- not pinned inside a narrow, name-width centered label.
   procedure Test_Large_Icons_Rename_Caret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Large_Icons);
      Cell     : Item_Layout;
      Found    : Boolean := False;
   begin
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Selected := True;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      Snapshot.Selected_Count := 1;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;
      Snapshot.Rename_Text := To_Unbounded_String ("a-much-longer-renamed-file-name.txt");

      declare
         Layout : constant Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Cells  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Snapshot, Layout, 20);
      begin
         for C of Cells loop
            if C.Visible_Index = 1 then
               Cell := C;
               Found := True;
            end if;
         end loop;
      end;
      Assert (Found, "the renamed large-icons cell is laid out");

      --  With the cursor at the start, the caret must sit at the cell's left
      --  edge (left-aligned edit), not indented to a centered name-width label.
      Snapshot.Text_Cursor_Position := 0;
      declare
         Frame          : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         CX, CY, CW, CH : Natural;
         Caret_Found    : Boolean;
      begin
         Find_Caret (Frame, CX, CY, CW, CH, Caret_Found);
         Assert (Caret_Found, "the focused large-icons rename draws a caret");
         Assert
           (CX >= Cell.X and then CX + CW <= Cell.X + Cell.Width,
            "the rename caret stays within the cell horizontally");
         Assert
           (CY >= Cell.Text_Y and then CY + CH <= Cell.Y + Cell.Height,
            "the rename caret sits on the label line inside the cell");
         Assert
           (CX <= Cell.X + 20,
            "the large-icons rename edits from the cell's left edge, not a centered label box");
      end;

      --  With the cursor further along, the caret tracks the text rightward,
      --  proving the editable box spans the cell rather than a tiny label.
      Snapshot.Text_Cursor_Position := 8;
      declare
         Frame          : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         CX, CY, CW, CH : Natural;
         Caret_Found    : Boolean;
      begin
         Find_Caret (Frame, CX, CY, CW, CH, Caret_Found);
         Assert (Caret_Found, "the rename caret is drawn as the text grows");
         Assert
           (CX > Cell.X + 20,
            "the caret advances rightward with the text across the wide rename field");
         Assert
           (CX + CW <= Cell.X + Cell.Width and then CY + CH <= Cell.Y + Cell.Height,
            "the advanced caret stays contained in the cell's label region");
      end;
   end Test_Large_Icons_Rename_Caret;

   --  Bug 14: the text-input caret height must scale with the font/line height,
   --  the way the glyph height does, rather than being a fixed size.
   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Caret_H (L : Positive) return Natural is
         Snapshot : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         X, Y, W, H : Natural;
         Found      : Boolean;
      begin
         Snapshot.Focus := Files.Types.Focus_Path_Input;
         Snapshot.Path_Input_Text := To_Unbounded_String ("/home/user/example");
         Snapshot.Text_Cursor_Position := 4;
         Find_Caret (Build_Frame_Commands (Snapshot, 1000, 800, L), X, Y, W, H, Found);
         return (if Found then H else 0);
      end Caret_H;

      Small : constant Natural := Caret_H (20);
      Large : constant Natural := Caret_H (40);
   begin
      Assert (Small > 0 and then Large > 0, "a focused path input draws a caret at each font size");
      Assert (Large > Small, "the caret grows taller with a larger font/line height");
      --  A fixed-size caret would keep Large = Small; require the growth to
      --  track the line-height increase rather than a token amount.
      Assert
        (Large - Small >= (40 - 20) / 2,
         "the caret height tracks the line height instead of a fixed size");
      --  The caret height must be PROPORTIONAL to the line height (a constant
      --  fraction), not line-height-minus-a-fixed-inset which under-scales the
      --  caret at small fonts. Cross-multiplying, Small/20 must equal Large/40
      --  within integer rounding (this fails for a Line_Height-minus-constant
      --  caret, which is stubbier at small fonts).
      Assert
        (abs (Integer (Small) * 40 - Integer (Large) * 20) <= 40,
         "the caret height stays a constant fraction of the line height across font sizes");
   end Test_Caret_Scales_With_Line_Height;

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

   --  Item 8/9 invariant: the bottom bar renders the localized hidden-count
   --  label carrying the snapshot's Hidden_Count, and exposes the count region
   --  as an accessible toggle button -- checked semantically, without exact
   --  pixels or colors.
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Contains (Haystack : String; Needle : String) return Boolean is
      begin
         if Needle'Length = 0 or else Needle'Length > Haystack'Length then
            return Needle'Length = 0;
         end if;

         for Start in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
            if Haystack (Start .. Start + Needle'Length - 1) = Needle then
               return True;
            end if;
         end loop;

         return False;
      end Contains;

      Hidden_Word  : constant String := Files.Localization.Text ("status.hidden");
      Toggle_Name  : constant String :=
        Files.Localization.Text (Files.Commands.Name_Key (Files.Commands.Toggle_Hidden_Files_Command));
      Snapshot     : View_Snapshot := Sample_Snapshot (5, Files.Types.Small_Icons);
      Frame        : Frame_Commands;
      Status_Text  : Unbounded_String;
      Found_Status : Boolean := False;
      Found_Button : Boolean := False;
   begin
      Snapshot.Hidden_Count := 7;
      Snapshot.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Frame := Build_Frame_Commands (Snapshot, Width => 1000, Height => 800, Line_Height => 20);

      for Command of Frame.Text loop
         if Contains (To_String (Command.Text), Hidden_Word) then
            Status_Text  := Command.Text;
            Found_Status := True;
         end if;
      end loop;
      Assert (Found_Status, "the bottom bar renders the localized hidden-count label");
      Assert (Contains (To_String (Status_Text), "7"), "the hidden-count label reflects the snapshot hidden count");

      for Node of Frame.Accessibility loop
         if Node.Role = Role_Button and then To_String (Node.Name) = Toggle_Name then
            Found_Button := True;
         end if;
      end loop;
      Assert (Found_Button, "the bottom-bar hidden count is exposed as an accessible toggle button");
   end Test_Bottom_Bar_Hidden_Count;

   --  True when the frame's base layer carries a hover-colored fill anchored at
   --  Cell's top-left corner -- the main-grid item hover highlight. Context-menu
   --  row hovers live in the overlay layer, so they never match here.
   function Cell_Has_Hover_Highlight
     (Frame : Frame_Commands;
      Cell  : Item_Layout)
      return Boolean is
   begin
      for Rect of Frame.Rectangles loop
         if Rect.Color = Hover_Color and then Rect.X = Cell.X and then Rect.Y = Cell.Y then
            return True;
         end if;
      end loop;
      return False;
   end Cell_Has_Hover_Highlight;

   --  True when the frame exposes a Role_Button accessibility node anchored at
   --  Close's corner (theme-proof: role and layout-derived position, not color).
   function Has_Close_Button_Node
     (Frame : Frame_Commands;
      Close : Close_Button_Layout)
      return Boolean is
   begin
      for Node of Frame.Accessibility loop
         if Node.Role = Role_Button and then Node.X = Close.X and then Node.Y = Close.Y then
            return True;
         end if;
      end loop;
      return False;
   end Has_Close_Button_Node;

   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base   : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      Layout : constant Layout_Metrics := Calculate_Layout (Base, 1000, 800, 20);
      Items  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Base, Layout, 20);
      Cell   : Item_Layout;
      Found  : Boolean := False;
   begin
      for C of Items loop
         if C.Visible_Index = 2 then
            Cell  := C;
            Found := True;
         end if;
      end loop;
      Assert (Found, "a layout cell exists for the hovered item");

      declare
         HX           : constant Natural := Cell.X + Cell.Width / 2;
         HY           : constant Natural := Cell.Y + Cell.Height / 2;
         Menu_Open    : View_Snapshot := Base;
         Closed_Frame : constant Frame_Commands :=
           Build_Frame_Commands
             (Base, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
      begin
         Assert
           (Cell_Has_Hover_Highlight (Closed_Frame, Cell),
            "with no context menu the hovered cell shows the main-grid hover highlight");

         Menu_Open.Context_Menu_Open := True;
         declare
            Open_Frame : constant Frame_Commands :=
              Build_Frame_Commands
                (Menu_Open, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Assert
              (not Cell_Has_Hover_Highlight (Open_Frame, Cell),
               "with the context menu open the hovered main-grid cell shows no hover highlight");
         end;
      end;
   end Test_Context_Menu_Suppresses_Item_Hover;

   procedure Test_Panels_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  Command palette.
      declare
         Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout  : Layout_Metrics;
         Palette : Command_Palette_Layout;
         Close   : Close_Button_Layout;
         Frame   : Frame_Commands;
      begin
         Snap.Command_Palette_Open := True;
         Layout  := Calculate_Layout (Snap, Width, Height, LH);
         Palette := Calculate_Command_Palette_Layout (Layout, LH);
         Close   := Panel_Close_Button (Palette.X, Palette.Y, Palette.Width, Palette.Height, LH);
         Frame   := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the command palette hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open command palette emits a close-button accessibility node");
      end;

      --  Settings pane.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Layout_Metrics;
         Pane   : Files.UI.Settings_Pane_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Settings_Pane_Open := True;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Pane   := Files.UI.Calculate_Settings_Pane_Layout (Width, Height, Layout.Toolbar_Height, LH);
         Close  := Panel_Close_Button (Pane.X, Pane.Y, Pane.Width, Pane.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the settings pane hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open settings pane emits a close-button accessibility node");
      end;

      --  Info pane.
      declare
         Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout  : Layout_Metrics;
         Info    : Info_Pane_Layout;
         Panel_W : Natural;
         Close   : Close_Button_Layout;
         Frame   : Frame_Commands;
      begin
         Snap.Info_Pane_Open := True;
         Layout  := Calculate_Layout (Snap, Width, Height, LH);
         Info    := Calculate_Info_Pane_Layout (Snap, Layout, LH);
         Panel_W :=
           (if Info.Scrollbar_Visible and then Info.Width > Info.Scrollbar_Width
            then Info.Width - Info.Scrollbar_Width
            else Info.Width);
         Close   := Panel_Close_Button (Info.X, Info.Y, Panel_W, Info.Height, LH);
         Frame   := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the info pane hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open info pane emits a close-button accessibility node");
      end;

      --  Root selector.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Layout_Metrics;
         Root   : Root_Selector_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Root_Selector_Open := True;
         for Index in 1 .. 3 loop
            Snap.Root_Paths.Append (To_Unbounded_String ("/root" & Integer'Image (Index)));
            Snap.Root_Labels.Append (To_Unbounded_String ("Root" & Integer'Image (Index)));
         end loop;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Root   := Calculate_Root_Selector_Layout (Snap, Layout, LH);
         Close  := Panel_Close_Button (Root.X, Root.Y, Root.Width, Root.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the root selector hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open root selector emits a close-button accessibility node");
      end;
   end Test_Panels_Expose_Close_Button;

   --  The palette is theme-aware through Files.Rendering.Color_For. This is a
   --  legitimate palette assertion (the role-to-color mapping), not a fragile
   --  whole-frame color assertion: the light theme must differ from dark for a
   --  representative role, and high contrast must keep the dark base so its
   --  rendering is not regressed.
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Rendering.Palette_Color;
      Dark_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Dark);
      Light_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Light);
      Dark_Text   : constant Palette_Color := Color_For (Text_Color, Theme_Dark);
      Light_Text  : constant Palette_Color := Color_For (Text_Color, Theme_Light);
   begin
      Assert
        (Light_Canvas /= Dark_Canvas,
         "the light theme uses a different canvas color than dark");
      Assert
        (Light_Text /= Dark_Text,
         "the light theme uses a different text color than dark");
      Assert
        (Light_Canvas.R > Dark_Canvas.R,
         "the light theme canvas is lighter than the dark canvas");
      Assert
        (Light_Text.R < Dark_Text.R,
         "the light theme text is darker than the dark text");
      Assert
        (Color_For (Canvas_Color, Theme_High_Contrast) = Dark_Canvas,
         "high contrast keeps the dark base canvas color (no regression)");
      Assert
        (Color_For (Canvas_Color) = Dark_Canvas,
         "the palette defaults to the dark theme");
   end Test_Theme_Palette_Selection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Rendering_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Rendering;
