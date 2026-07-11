with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with System;

with Files.Commands;
with Files.Events;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.UI;
with Files.UTF8;
with Files.Quick_Look;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Types;
with Guikit.Layout;

--  Rendering tests expressed as layout INVARIANTS and behaviours rather than
--  exact pixel coordinates. Each routine constructs its own deterministic view
--  snapshot, so there is no shared mutable state between tests, and the
--  assertions survive intentional visual-design changes (margins, insets, row
--  strides, scrollbar widths) while still catching genuine layout regressions.
package body Files_Suite.Rendering is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use Files.Rendering;
   use Guikit.Draw;
   use type Files.Commands.Command_Id;
   use type Files.Rendering.Context_Menu_Row_Kind;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Types.Focus_Target;
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
   procedure Test_Multi_Rename_Fields_And_Carets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Show_Extensions_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_Click_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Panels_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Column_Customization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Group_Header_Rows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Header_Separator_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Separators_Within_Content (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Text_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sort_Button_Fits_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Sort_Label_Centered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Separate_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Counts_Text_Uses_Active_Color (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Counts_Tooltip_Explains_Numbers (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Has_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Outside_Toggle_Hover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Split_Status_Region (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Free_Space_Click_Toggles (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Used_Space_Label_After_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Counts_Compact_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Column_Reorder_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Star_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Grid_Dots (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Items_In_Rect (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Frame_Draws_Rectangle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Details_Header_Text_Centered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Overlay_Content (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Image_High_Res (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Multi_Rename_Fields_And_Carets'Access,
         "two renaming rows draw two rename fields and two carets at their own cursors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Show_Extensions_Toggle'Access,
         "Show_Extensions off drops a file's extension for display but keeps dotfiles and folders whole");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret_Click_Round_Trip'Access,
         "a click at a drawn caret pixel resolves back to that caret's cursor index");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Caret_Scales_With_Line_Height'Access, "the text-input caret height grows with the line height");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Click_Translation_Behavior'Access, "click translation behaviour");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Glyph_Rasterization'Access, "frame text rasterizes through textrender");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Vulkan_Submission'Access, "frame builds a vulkan submission batch");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Hidden_Count'Access, "bottom bar reflects the hidden count and exposes a toggle button");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Free_Space'Access,
         "bottom bar shows filesystem free space when known and omits it when unknown");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Selection_Summary'Access,
         "bottom bar shows the selection count and summed size when items are selected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Suppresses_Item_Hover'Access,
         "an open context menu suppresses the main-grid item hover highlight");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tooltip_Wraps_When_Narrow'Access,
         "a narrow window wraps a long tooltip onto multiple rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Separators'Access,
         "the item context menu groups its commands with non-selectable separators");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Panels_Expose_Close_Button'Access,
         "each open overlay panel emits a close-button accessibility node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Overlay_Content'Access,
         "the quick look overlay emits its dialog panel and previewed content");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Image_High_Res'Access,
         "a quick look image preview uses the full-resolution image and aspect ratio");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Drawn_In_Overlay'Access,
         "the quick look panel composites in the overlay layer, not the main grid layer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Theme_Palette_Selection'Access,
         "the light palette differs from dark while high contrast keeps the dark base");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Column_Customization'Access,
         "detail columns honour visibility and custom widths and always keep the name column");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Group_Header_Rows'Access,
         "grouping emits non-selectable header rows that click-testing skips");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Header_Separator_Hit_Test'Access,
         "a header column boundary hit-tests to its resize separator and misses elsewhere");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Separators_Within_Content'Access,
         "an overflowing details view keeps its column dividers inside the content, out of the bottom bar");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Text_Baseline'Access,
         "the view-mode chooser labels share the bottom bar's text baseline");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sort_Button_Fits_Field'Access,
         "the sort button is sized to the active field while the sort menu fits the widest");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Sort_Label_Centered'Access,
         "the sort field label and its arrow are horizontally centred in the sort button");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Free_Space_Separate_Field'Access,
         "free space is its own field, divided from the counts by a divider");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Counts_Text_Uses_Active_Color'Access,
         "the counts text uses the active control colour, not the muted info colour");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Counts_Tooltip_Explains_Numbers'Access,
         "the counts tooltip explains the meaning of the three numbers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Free_Space_Has_Tooltip'Access,
         "the free-space field has its own tooltip");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Free_Space_Outside_Toggle_Hover'Access,
         "the free-space field is outside the hidden-files toggle hover region");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Split_Status_Region'Access,
         "Split_Status_Region carves the free-space field off the toggle area");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Free_Space_Click_Toggles'Access,
         "clicking the free-space field toggles free/used space; counts still toggles hidden files");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Used_Space_Label_After_Toggle'Access,
         "used-space mode shows the used-space suffix, not the free-space one");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Counts_Compact_When_Narrow'Access,
         "a narrow bar drops the count labels and slash-separates the numbers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Detail_Column_Reorder_Layout'Access,
         "a reordered column order lays columns out left-to-right in that order with widths following the column");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Favorite_Star_Indicators'Access,
         "favorited items draw a gold grid star and the path bar draws a filled vs empty star by current-dir state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Color_Label_Grid_Dots'Access,
         "labeled items draw a colored corner dot in the label color; unlabeled items draw none");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee_Items_In_Rect'Access,
         "a marquee rectangle intersects exactly the item cells it touches and normalizes any drag direction");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee_Frame_Draws_Rectangle'Access,
         "an active marquee draws a translucent selection rectangle over the grid");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Details_Header_Text_Centered'Access,
         "details header labels are optically centred like the bottom-bar text");
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

   --  The details-view header labels are optically centred in the header field
   --  using the same vertical offset as the (accepted) bottom-bar text, rather
   --  than sitting low at the full geometric inset.
   procedure Test_Details_Header_Text_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Mod_Lbl  : constant String := Files.Localization.Text ("details.modified");
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
      Bottom_Top : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;

      Header_Field_Top : Integer := -1;   --  top of the header background band
      Header_Text_Y    : Integer := -1;
      Bottom_Text_Y    : Integer := -1;
   begin
      --  Header background: the topmost content-width band (not a hairline).
      for R of Frame.Rectangles loop
         if R.Width in 900 .. 999 and then R.Height > 10 and then R.Y < Bottom_Top
           and then (Header_Field_Top < 0 or else R.Y < Header_Field_Top)
         then
            Header_Field_Top := R.Y;
         end if;
      end loop;
      for C of Frame.Text loop
         if To_String (C.Text) = Mod_Lbl then
            Header_Text_Y := C.Y;
         elsif C.Y >= Bottom_Top and then (Bottom_Text_Y < 0 or else C.Y < Bottom_Text_Y) then
            Bottom_Text_Y := C.Y;
         end if;
      end loop;
      Assert (Header_Field_Top >= 0 and then Header_Text_Y >= 0 and then Bottom_Text_Y >= 0,
              "the header field, header label and a bottom-bar label are all present");
      --  Same offset within their fields: both optically centred alike.
      Assert (Header_Text_Y - Header_Field_Top = Bottom_Text_Y - Bottom_Top,
              "the header label sits at the same vertical offset as the bottom-bar text");
   end Test_Details_Header_Text_Centered;

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

   --  True when the frame emits an overlay rectangle at exactly (X, Y) with the
   --  given width and height (used to check the progress bar's filled portion).
   function Has_Overlay_Rect_At
     (Frame  : Frame_Commands;
      X      : Natural;
      Y      : Natural;
      Width  : Natural;
      Height : Natural)
      return Boolean is
   begin
      for Rect of Frame.Overlay_Rectangles loop
         if Rect.X = X and then Rect.Y = Y
           and then Rect.Width = Width and then Rect.Height = Height
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Overlay_Rect_At;

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Modes : constant array (1 .. 3) of Files.Types.View_Mode :=
        (Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details);
   begin
      for Mode of Modes loop
         declare
            Snapshot : constant View_Snapshot := Sample_Snapshot (6, Mode);
            Layout   : constant Guikit.Draw.Layout_Metrics :=
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
      Few_L  : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Few, 1000, 800, 20);
      Few_MV : constant Main_View_Layout := Calculate_Main_View_Layout (Few, Few_L, 20);
   begin
      Assert (not Few_MV.Scrollbar_Visible, "no scrollbar is shown when content fits the viewport");

      declare
         Many   : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Many, 400, 160, 20);
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
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Mid, 900, 400, 20);
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
            Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Top, 400, 160, 20);
            MV_Top : constant Main_View_Layout := Calculate_Main_View_Layout (Top, Layout, 20);
            MV_Bot : constant Main_View_Layout := Calculate_Main_View_Layout (Bottom, Layout, 20);
         begin
            Assert (MV_Bot.Scroll_Pixels >= MV_Top.Scroll_Pixels, "scrolling further never scrolls less");
            Assert (MV_Bot.Scroll_Pixels <= MV_Bot.Content_Height, "the scroll offset is bounded by content");
            --  Bug 16: the thumb reaches the exact ends of its track -- top at
            --  no scroll, bottom at max scroll -- so the track and content stay
            --  aligned.
            Assert
              (MV_Top.Scrollbar_Thumb_Y = MV_Top.Scrollbar_Y,
               "at the top the thumb sits exactly at the track top");
            Assert
              (MV_Bot.Scrollbar_Thumb_Y + MV_Bot.Scrollbar_Height
                 = MV_Bot.Scrollbar_Y + MV_Bot.Scrollbar_Track_Height,
               "at max scroll the thumb reaches exactly the track bottom");
         end;
      end;

      --  Bug 16: the details scrollbar track excludes the sticky column header
      --  (rows scroll below it), so its track starts lower than an equivalent
      --  header-less icons view over the same layout.
      declare
         D_Snap : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         I_Snap : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Large_Icons);
         L      : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (D_Snap, 400, 300, 20);
         D_MV   : constant Main_View_Layout := Calculate_Main_View_Layout (D_Snap, L, 20);
         I_MV   : constant Main_View_Layout := Calculate_Main_View_Layout (I_Snap, L, 20);
      begin
         Assert
           (D_MV.Scrollbar_Visible and then I_MV.Scrollbar_Visible,
            "both the details and icons views overflow their viewport");
         Assert
           (D_MV.Scrollbar_Y > I_MV.Scrollbar_Y,
            "the details scrollbar track starts below the sticky column header");
      end;

      --  Regression: the last row must be reachable (laid out with non-zero
      --  height) at maximum scroll. Row-period snapping must not floor the
      --  offset below the point that brings the final, partially-fitting row
      --  fully into view, in any view mode.
      for Mode in Files.Types.View_Mode loop
         declare
            Full  : View_Snapshot := Sample_Snapshot (60, Mode);
            L     : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Full, 400, 300, 20);
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
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
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
      Layout   : Guikit.Draw.Layout_Metrics;
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
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("a-much-longer-renamed-file-name.txt");
         Item.Rename_Cursor := 0;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      Snapshot.Selected_Count := 1;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;

      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
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
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Rename_Cursor := 0;
         Snapshot.Items.Replace_Element (1, Item);
      end;
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
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Rename_Cursor := 8;
         Snapshot.Items.Replace_Element (1, Item);
      end;
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

   --  A synchronized multi-rename must draw one field and one caret per renaming
   --  row, each caret at that row's own cursor.
   procedure Test_Multi_Rename_Fields_And_Carets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Carets   : Natural := 0;
      First_X  : Natural := 0;
      Second_X : Natural := 0;

      procedure Set_Rename (Index : Positive; Cursor : Natural) is
         Item : Item_Snapshot := Snapshot.Items.Element (Index);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("abcdef");
         Item.Rename_Cursor := Cursor;
         Snapshot.Items.Replace_Element (Index, Item);
      end Set_Rename;
   begin
      Set_Rename (1, 1);
      Set_Rename (2, 4);
      Snapshot.Selected_Count := 2;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;

      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         for Rect of Frame.Rectangles loop
            if Rect.Width in 1 .. 2 and then Rect.Color = Text_Color then
               Carets := Carets + 1;
               if First_X = 0 then
                  First_X := Rect.X;
               else
                  Second_X := Rect.X;
               end if;
            end if;
         end loop;
      end;

      Assert (Carets = 2, "two renaming rows draw exactly two carets");
      --  The two rows share the same text but differ by three cursor cells, so
      --  their carets sit three advance-widths apart.
      Assert
        (Natural'Max (First_X, Second_X) - Natural'Min (First_X, Second_X)
           = 3 * Guikit.Layout.Caret_Advance_Width (20),
         "each row's caret tracks that row's own cursor position");
   end Test_Multi_Rename_Fields_And_Carets;

   procedure Test_Show_Extensions_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Has_Text (Frame : Frame_Commands; S : String) return Boolean is
      begin
         for Cmd of Frame.Text loop
            if To_String (Cmd.Text) = S then
               return True;
            end if;
         end loop;
         return False;
      end Has_Text;

      function Rendered (Name : String; Kind : Files.Types.Item_Kind; Show_Ext : Boolean) return Frame_Commands is
         Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
         Item     : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Name := To_Unbounded_String (Name);
         Item.Kind := Kind;
         Snapshot.Items.Replace_Element (1, Item);
         Snapshot.Show_Extensions := Show_Ext;
         return Build_Frame_Commands (Snapshot, 1000, 800, 20);
      end Rendered;
   begin
      Assert (Has_Text (Rendered ("readme.txt", Files.Types.Regular_File_Item, True), "readme.txt"),
              "with extensions on the full name is shown");

      declare
         Frame : constant Frame_Commands := Rendered ("readme.txt", Files.Types.Regular_File_Item, False);
      begin
         Assert (Has_Text (Frame, "readme"), "with extensions off the trailing extension is dropped");
         Assert (not Has_Text (Frame, "readme.txt"), "with extensions off the full name is not drawn");
      end;

      --  A name that is only a leading-dot extension keeps its whole name.
      Assert (Has_Text (Rendered (".bashrc", Files.Types.Regular_File_Item, False), ".bashrc"),
              "a dotfile stays fully visible with extensions off");

      --  Directory names are never stripped, even when they contain a dot.
      Assert (Has_Text (Rendered ("my.folder", Files.Types.Directory_Item, False), "my.folder"),
              "a folder keeps its dotted name with extensions off");
   end Test_Show_Extensions_Toggle;

   --  The caret renderer and the click hit-test measure text with one shared
   --  advance width, so a click at the pixel a caret draws for cursor k must
   --  resolve back to cursor k.
   procedure Test_Caret_Click_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      CX, CY, CW, CH : Natural;
      Found          : Boolean;
   begin
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("abcdef");
         Item.Rename_Cursor := 3;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      Snapshot.Selected_Count := 1;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;

      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         Find_Caret (Frame, CX, CY, CW, CH, Found);
         Assert (Found, "the focused rename row draws a caret");
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame,
                 X      => CX,
                 Y      => CY + CH / 2,
                 Width  => 1000,
                 Height => 800);
         begin
            Assert
              (Action.Kind = Files.Events.Text_Click_Input_Action,
               "clicking the rename field produces a text-click action");
            Assert
              (Action.Focus_Target = Files.Types.Focus_Rename_Input,
               "the click targets the rename input");
            Assert
              (Action.Cursor_Position = 3,
               "the click at the caret pixel resolves back to the drawn cursor index");
            Assert (Action.Item_Index = 1, "the click carries the clicked row index");
         end;
      end;
   end Test_Caret_Click_Round_Trip;

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
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
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
      Last     : constant Item_Layout := Items.Element (Items.Last_Index);
      Empty_Y  : constant Natural := Last.Y + Last.Height + 20;
      Off_Item : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame,
           X => Layout.Main_X + 20, Y => Empty_Y, Width => 1000, Height => 800);
      Outside  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Click
          (Snapshot, Frame, X => 999, Y => 799, Width => 1000, Height => 800);
   begin
      Assert
        (On_Item.Kind /= Files.Events.No_Input_Action,
         "clicking an item produces an input action");
      Assert
        (Empty_Y < Layout.Main_Y + Layout.Main_Height,
         "the six-row list leaves empty grid space below its last row");
      Assert
        (Off_Item.Kind = Files.Events.Marquee_Begin_Input_Action,
         "pressing empty grid space begins a rubber-band marquee");
      Assert
        (Outside.Kind /= Files.Events.Marquee_Begin_Input_Action,
         "pressing the chrome outside the grid never begins a marquee");
   end Test_Click_Translation_Behavior;
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Result   : Guikit.Draw.Text_Render_Result;
   begin
      Assert (Files.Fonts.Default_Font_Path /= "", "a default text font is available");
      Assert
        (Initialize_Text
           (Renderer    => Renderer,
            Font_Path   => Files.Fonts.Default_Font_Path,
            Pixel_Size  => 16,
            Cell_Width  => 10,
            Cell_Height => 20) = Guikit.Draw.Text_Render_Success,
         "the text renderer loads the default font");
      Result := Build_Text_Glyphs (Renderer, Frame);
      Assert (Result.Status = Guikit.Draw.Text_Render_Success, "frame text rasterizes through textrender");
      Assert (Natural (Result.Glyphs.Length) > 0, "the text renderer emits glyph draw commands");
      Assert (Result.Atlas_Pixels /= System.Null_Address, "the text renderer exposes an atlas");
   end Test_Text_Glyph_Rasterization;

   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Renderer : Text_Renderer;
      Text     : Guikit.Draw.Text_Render_Result;
      Batch    : Guikit.Vulkan.Submission_Batch;
   begin
      Assert
        (Initialize_Text (Renderer, Files.Fonts.Default_Font_Path, 16, 10, 20) = Guikit.Draw.Text_Render_Success,
         "the text renderer initialises for submission");
      Text  := Build_Text_Glyphs (Renderer, Frame);
      Batch := Guikit.Vulkan.Build_Submission
        (Rectangles         => Frame.Rectangles,
         Triangles          => Frame.Triangles,
         Icons              => Frame.Icons,
         Overlay_Rectangles => Frame.Overlay_Rectangles,
         Layout             => Frame.Layout,
         Theme              => Frame.Theme_Palette,
         Text               => Text);
      Assert (Batch.Width = Frame.Layout.Width, "the vulkan batch preserves the frame width");
      Assert (Batch.Height = Frame.Layout.Height, "the vulkan batch preserves the frame height");
      Assert
        (Batch.Rectangle_Vertex_Count = Natural (Frame.Rectangles.Length) * 6,
         "each rectangle expands to two triangles (six vertices)");
      Assert (Batch.Glyph_Vertex_Count > 0, "rasterized glyphs reach the vulkan submission batch");
   end Test_Vulkan_Submission;
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

   --  True when any text command in the frame contains Needle.
   function Frame_Has_Text (Frame : Frame_Commands; Needle : String) return Boolean is
   begin
      for Command of Frame.Text loop
         if Contains (To_String (Command.Text), Needle) then
            return True;
         end if;
      end loop;
      --  Overlay panels (command palette, settings, Quick Look) draw their text
      --  into the overlay layer, so a "does the frame show this text" check must
      --  cover both layers.
      for Command of Frame.Overlay_Text loop
         if Contains (To_String (Command.Text), Needle) then
            return True;
         end if;
      end loop;
      return False;
   end Frame_Has_Text;
   --  The grouping field (index 9) is laid out as two rows: a label row and a
   --  dedicated segment row spanning the full content width. The five option
   --  segments (None / Type / Modified / Size / Label) therefore sit on their
   --  own row BELOW the label and together span the whole control width (each
   --  roughly a fifth), instead of being squeezed into a partial width shared
   --  with the label. They render even when the field is not the focused one,
   --  so the measured content height -- and thus the scroll bound -- always
   --  accounts for the extra row.
   --  A click on a grouping option segment resolves through the hit-test to that
   --  option (field 9, the clicked option index) at the segment's new row Y --
   --  the same field/option the events layer feeds to Settings_Click -- so
   --  choosing a grouping mode still works after the layout split.
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Free_Word : constant String := Files.Localization.Text ("status.free_space.suffix");
      Gib_Unit  : constant String := Files.Localization.Text ("details.size.unit.gib");
      Known     : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Unknown   : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Frame     : Frame_Commands;
   begin
      --  A known free-space value renders the "<X GB> free" indicator.
      Known.Free_Space_Known := True;
      Known.Free_Space_Bytes := 3 * 1024 * 1024 * 1024;
      Known.Total_Space_Bytes := 8 * 1024 * 1024 * 1024;
      Frame := Build_Frame_Commands (Known, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Free_Word),
              "the bottom bar renders the localized free-space suffix when free space is known");
      Assert (Frame_Has_Text (Frame, Gib_Unit),
              "the free-space indicator formats the value with the shared size unit");

      --  An unknown (unreported) value emits no free-space text at all.
      Unknown.Free_Space_Known := False;
      Unknown.Free_Space_Bytes := 0;
      Frame := Build_Frame_Commands (Unknown, Width => 1200, Height => 800, Line_Height => 20);
      Assert (not Frame_Has_Text (Frame, Free_Word),
              "the bottom bar omits the free-space indicator when the value is unknown");
   end Test_Bottom_Bar_Free_Space;

   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Selected_Word : constant String := Files.Localization.Text ("status.selected");
      Mib_Unit      : constant String := Files.Localization.Text ("details.size.unit.mib");
      One_Mib       : constant Long_Long_Integer := 1024 * 1024;
      Snapshot      : View_Snapshot := Sample_Snapshot (5, Files.Types.Small_Icons);
      Frame         : Frame_Commands;

      procedure Mark_Selected (Index : Positive; Size : Long_Long_Integer) is
         Item : Item_Snapshot := Snapshot.Items.Element (Index);
      begin
         Item.Selected := True;
         Item.Size_Available := True;
         Item.Size := Size;
         Snapshot.Items.Replace_Element (Index, Item);
      end Mark_Selected;
   begin
      --  Free space is intentionally left unknown so the only size unit that can
      --  appear in the bar originates from the selection summary.
      Snapshot.Free_Space_Known := False;

      --  Neutral state: nothing selected shows the count without a size total.
      Snapshot.Selected_Count := 0;
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Selected_Word),
              "the bottom bar shows the selection label in the neutral state");
      Assert (not Frame_Has_Text (Frame, Mib_Unit),
              "the neutral bottom bar shows no selection size total");

      --  Three selected items with known sizes summing to 3 MB.
      Mark_Selected (1, One_Mib);
      Mark_Selected (2, One_Mib);
      Mark_Selected (3, One_Mib);
      Snapshot.Selected_Count := 3;
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Assert (Frame_Has_Text (Frame, Selected_Word),
              "the bottom bar shows the selection label when items are selected");
      Assert (Frame_Has_Text (Frame, "3"),
              "the bottom bar reflects the selection count");
      Assert (Frame_Has_Text (Frame, Mib_Unit),
              "the bottom bar shows the summed size of the selected items");
   end Test_Bottom_Bar_Selection_Summary;

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
      Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Base, 1000, 800, 20);
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

   --  Hover the toolbar button whose tooltip text is longest, then count the
   --  overlay rows that render that tooltip: a narrow window wraps it onto
   --  several rows, a wide one keeps it on a single row.
   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);

      --  Centre of the longest-text tooltip region in the frame.
      procedure Longest_Tooltip
        (Frame : Frame_Commands; HX, HY : out Natural;
         Text : out Ada.Strings.Unbounded.Unbounded_String; Found : out Boolean)
      is
         Best : Natural := 0;
      begin
         HX := 0;
         HY := 0;
         Text := Ada.Strings.Unbounded.Null_Unbounded_String;
         Found := False;
         for C of Frame.Tooltips loop
            if Files.UTF8.Display_Units (To_String (C.Text)) > Best then
               Best := Files.UTF8.Display_Units (To_String (C.Text));
               HX := C.X + C.Width / 2;
               HY := C.Y + C.Height / 2;
               Text := C.Text;
               Found := True;
            end if;
         end loop;
      end Longest_Tooltip;

      --  Overlay rows whose text is a slice of the tooltip's text (its wrapped
      --  lines), i.e. how many rows the tooltip occupies.
      function Tooltip_Rows (Frame : Frame_Commands; Full : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Frame.Overlay_Text loop
            if Length (C.Text) > 0 and then Ada.Strings.Fixed.Index (Full, To_String (C.Text)) > 0 then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Tooltip_Rows;

      --  The wrapped rows (in draw order) rejoined with single spaces.
      function Rows_Joined (Frame : Frame_Commands; Full : String) return String is
         Joined : Ada.Strings.Unbounded.Unbounded_String;
         First  : Boolean := True;
      begin
         for C of Frame.Overlay_Text loop
            if Length (C.Text) > 0 and then Ada.Strings.Fixed.Index (Full, To_String (C.Text)) > 0 then
               if not First then
                  Ada.Strings.Unbounded.Append (Joined, ' ');
               end if;
               Ada.Strings.Unbounded.Append (Joined, C.Text);
               First := False;
            end if;
         end loop;
         return Ada.Strings.Unbounded.To_String (Joined);
      end Rows_Joined;

      --  Collapse whitespace runs to single spaces and trim.
      function Squeeze (S : String) return String is
         R          : Ada.Strings.Unbounded.Unbounded_String;
         Prev_Space : Boolean := True;
      begin
         for Ch of S loop
            if Ch = ' ' or else Ch = ASCII.LF or else Ch = ASCII.CR or else Ch = ASCII.HT then
               if not Prev_Space then
                  Ada.Strings.Unbounded.Append (R, ' ');
                  Prev_Space := True;
               end if;
            else
               Ada.Strings.Unbounded.Append (R, Ch);
               Prev_Space := False;
            end if;
         end loop;
         declare
            Str : constant String := Ada.Strings.Unbounded.To_String (R);
         begin
            return (if Str'Length > 0 and then Str (Str'Last) = ' '
                    then Str (Str'First .. Str'Last - 1) else Str);
         end;
      end Squeeze;

      HX, HY : Natural;
      Tip    : Ada.Strings.Unbounded.Unbounded_String;
      Found  : Boolean;
   begin
      declare
         Probe : constant Frame_Commands := Build_Frame_Commands (Base, 260, 800, 20);
      begin
         Longest_Tooltip (Probe, HX, HY, Tip, Found);
         Assert (Found and then Files.UTF8.Display_Units (To_String (Tip)) >= 24,
                 "a long toolbar tooltip is present in a narrow window");
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Base, 260, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Assert (Tooltip_Rows (Frame, To_String (Tip)) >= 2,
                    "a narrow window wraps the tooltip onto multiple rows");
            Assert (Squeeze (Rows_Joined (Frame, To_String (Tip))) = Squeeze (To_String (Tip)),
                    "wrapped rows rejoin to the original text (no mid-word breaks)");
         end;
      end;

      declare
         Probe : constant Frame_Commands := Build_Frame_Commands (Base, 1000, 800, 20);
      begin
         Longest_Tooltip (Probe, HX, HY, Tip, Found);
         Assert (Found, "a tooltip is present in a wide window");
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Base, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Assert (Tooltip_Rows (Frame, To_String (Tip)) = 1,
                    "a wide window shows the tooltip on a single row");
         end;
      end;
   end Test_Tooltip_Wraps_When_Narrow;

   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);

      --  The full set of real commands the item menu must still offer, in any
      --  order, regardless of the separators woven between the groups.
      Expected : constant array (1 .. 19) of Files.Commands.Command_Id :=
        [Files.Commands.Open_Selected_Items_Command,
         Files.Commands.Open_With_Command,
         Files.Commands.Open_Containing_Folder_Command,
         Files.Commands.Toggle_Favorite_Command,
         Files.Commands.Set_Color_Label_Command,
         Files.Commands.Copy_Selected_Items_Command,
         Files.Commands.Cut_Selected_Items_Command,
         Files.Commands.Copy_Path_Command,
         Files.Commands.Copy_To_Command,
         Files.Commands.Move_To_Command,
         Files.Commands.Duplicate_Selected_Command,
         Files.Commands.Compress_Zip_Command,
         Files.Commands.Compress_7z_Command,
         Files.Commands.Extract_Archive_Command,
         Files.Commands.Create_Symlink_Command,
         Files.Commands.Create_Hardlink_Command,
         Files.Commands.Rename_Selected_Items_Command,
         Files.Commands.Delete_Selected_Items_Command,
         Files.Commands.Restore_From_Trash_Command];
   begin
      Snapshot.Context_Menu_Open := True;
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu_Item;
      Snapshot.Context_Menu_X := 100;
      Snapshot.Context_Menu_Y := 100;

      declare
         Menu : constant Context_Menu_Layout :=
           Calculate_Context_Menu_Layout (Snapshot, 1000, 800, 20);
         Separator_Count : Natural := 0;
         Command_Count   : Natural := 0;
      begin
         Assert (Menu.Visible, "the item context menu is visible");
         Assert (Menu.Row_Count <= Max_Context_Menu_Rows, "the menu fits its fixed row array");
         Assert
           (Menu.Separator_Height > 0 and then Menu.Separator_Height < Menu.Row_Height,
            "separator rows are shorter than command rows");

         --  Every real command still appears exactly once on a command row.
         for Command of Expected loop
            declare
               Seen : Natural := 0;
            begin
               for Row in 1 .. Menu.Row_Count loop
                  if Menu.Row_Kinds (Row) = Command_Row
                    and then Menu.Commands (Row) = Command
                  then
                     Seen := Seen + 1;
                  end if;
               end loop;
               Assert (Seen = 1, "each grouped command appears exactly once");
            end;
         end loop;

         for Row in 1 .. Menu.Row_Count loop
            if Menu.Row_Kinds (Row) = Separator_Row then
               Separator_Count := Separator_Count + 1;
               --  A separator carries no command and is not selectable.
               Assert
                 (Menu.Commands (Row) = Files.Commands.No_Command,
                  "a separator row carries no command");
               declare
                  Probe_X : constant Natural := Menu.X + Menu.Width / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Separator_Height / 2;
               begin
                  Assert
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y) = 0,
                     "a hit test on a separator selects no row");
               end;
            else
               Command_Count := Command_Count + 1;
               --  A real command row hit-tests back to its own index.
               declare
                  Probe_X : constant Natural := Menu.X + Menu.Width / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Row_Height / 2;
               begin
                  Assert
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y) = Row,
                     "a hit test on a command row returns that row");
               end;
            end if;
         end loop;

         Assert (Command_Count = Expected'Length, "all real commands are laid out");
         Assert (Separator_Count = 5, "five separators divide the six command groups");
      end;
   end Test_Context_Menu_Separators;

   procedure Test_Panels_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  Info pane.
      declare
         Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout  : Guikit.Draw.Layout_Metrics;
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
         Layout : Guikit.Draw.Layout_Metrics;
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

      --  Folder-tree sidebar.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Panel  : Tree_Panel_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Tree_Panel_Open := True;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Panel  := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Close  := Panel_Close_Button (Panel.X, Panel.Y, Panel.Width, Panel.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the folder tree hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open folder tree emits a close-button accessibility node");
      end;

      --  Quick Look overlay.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         QL     : Quick_Look_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("notes.txt");
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         QL     := Calculate_Quick_Look_Layout (Layout, LH);
         Close  := Panel_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the quick look overlay hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open quick look overlay emits a close-button accessibility node");
      end;

      --  Color-label picker overlay.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Picker : Label_Picker_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Label_Picker_Open := True;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Picker := Calculate_Label_Picker_Layout (Layout, LH);
         Close  := Panel_Close_Button (Picker.X, Picker.Y, Picker.Width, Picker.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the label picker hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open label picker emits a close-button accessibility node");
      end;

      --  Paste-conflict dialog.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Dialog : Conflict_Dialog_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Paste_Conflict_Open := True;
         Snap.Paste_Conflict_Name := To_Unbounded_String ("report.txt");
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Dialog := Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);
         Close  := Panel_Close_Button (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the paste-conflict dialog hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open paste-conflict dialog emits a close-button accessibility node");
         Assert
           (Conflict_Hit_At (Frame, Dialog.Replace_X + Dialog.Button_Width / 2,
              Dialog.Button_Y + Dialog.Button_Height / 2).Kind = Conflict_Hit_Replace,
            "the replace button is hit-testable at its center");
      end;

      --  Paste-progress overlay: exposes a Cancel affordance and a proportional
      --  progress bar while a long copy/move is in flight.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Panel  : Paste_Progress_Layout;
         Frame  : Frame_Commands;
         Expected_Fill : Natural;
      begin
         Snap.Paste_Progress_Open := True;
         Snap.Paste_Progress_Done := 3;
         Snap.Paste_Progress_Total := 10;
         Snap.Paste_Progress_Name := To_Unbounded_String ("bigfile.bin");
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Panel  := Calculate_Paste_Progress_Layout (Snap, Layout, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Expected_Fill := (Panel.Bar_Width * Snap.Paste_Progress_Done) / Snap.Paste_Progress_Total;
         Assert
           (Conflict_Hit_At (Frame, Panel.Cancel_X + Panel.Cancel_Width / 2,
              Panel.Cancel_Y + Panel.Cancel_Height / 2).Kind = Conflict_Hit_Progress_Cancel,
            "the paste-progress overlay exposes a hit-testable Cancel button");
         Assert (Expected_Fill > 0, "a partial progress produces a non-empty filled bar");
         Assert
           (Has_Overlay_Rect_At (Frame, Panel.Bar_X, Panel.Bar_Y, Expected_Fill, Panel.Bar_Height),
            "the progress bar's filled width is proportional to Done / Total");
      end;
   end Test_Panels_Expose_Close_Button;

   --  True when the frame exposes an accessibility node with the given role.
   function Frame_Has_Role
     (Frame : Frame_Commands;
      Role  : Accessibility_Role)
      return Boolean is
   begin
      for Node of Frame.Accessibility loop
         if Node.Role = Role then
            return True;
         end if;
      end loop;
      return False;
   end Frame_Has_Role;

   procedure Test_Quick_Look_Overlay_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  A text preview draws its dialog panel and the previewed lines.
      declare
         Snap  : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Text_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("readme.txt");
         Snap.Quick_Look_Text_Lines.Append (To_Unbounded_String ("first preview line"));
         Snap.Quick_Look_Text_Lines.Append (To_Unbounded_String ("second preview line"));
         Frame := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Frame_Has_Role (Frame, Role_Dialog), "the quick look overlay emits a dialog panel node");
         Assert (Frame_Has_Text (Frame, "readme.txt"), "the quick look title shows the item name");
         Assert (Frame_Has_Text (Frame, "first preview line"), "the quick look text body shows the first line");
      end;

      --  When closed the overlay draws nothing.
      declare
         Snap  : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         Assert (not Frame_Has_Text (Frame, "readme.txt"), "no quick look content is drawn when closed");
      end;
   end Test_Quick_Look_Overlay_Content;

   --  Quick Look composites in the overlay layer (on top of the grid), so its
   --  panel background is an overlay rectangle and its preview icon is flagged
   --  as an overlay icon; nothing leaks into the main layer under the grid.
   procedure Test_Quick_Look_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      QL     : Quick_Look_Layout;
      Frame  : Frame_Commands;

      function Panel_Bg_In (Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector) return Boolean is
      begin
         for R of Rects loop
            if R.Color = Pane_Color and then R.X = QL.X and then R.Y = QL.Y
              and then R.Width = QL.Width and then R.Height = QL.Height
            then
               return True;
            end if;
         end loop;
         return False;
      end Panel_Bg_In;

      Icon_Overlay : Boolean := False;
   begin
      Snap.Quick_Look_Open := True;
      Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
      Snap.Quick_Look_Name := To_Unbounded_String ("notes.txt");
      Snap.Quick_Look_Icon_Id := To_Unbounded_String ("document");
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      QL     := Calculate_Quick_Look_Layout (Layout, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);

      Assert (Panel_Bg_In (Frame.Overlay_Rectangles),
              "the quick look panel background is drawn in the overlay layer");
      Assert (not Panel_Bg_In (Frame.Rectangles),
              "the quick look panel background does not leak into the main layer under the grid");

      for Icon of Frame.Icons loop
         if Icon.Overlay then
            Icon_Overlay := True;
         end if;
      end loop;
      Assert (Icon_Overlay, "the quick look preview icon is flagged as an overlay icon");
   end Test_Quick_Look_Drawn_In_Overlay;

   --  A Quick Look image preview carries the full-resolution decoded image (not
   --  the 64px thumbnail) and draws at its aspect ratio.
   procedure Test_Quick_Look_Image_High_Res (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      IW     : constant Natural  := 200;
      IH     : constant Natural  := 150;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Frame  : Frame_Commands;
      Found  : Boolean := False;
   begin
      Snap.Quick_Look_Open := True;
      Snap.Quick_Look_Kind := Files.Quick_Look.Image_Content;
      Snap.Quick_Look_Name := To_Unbounded_String ("photo.png");
      Snap.Quick_Look_Icon_Id := To_Unbounded_String ("image");
      Snap.Quick_Look_Image_Width := IW;
      Snap.Quick_Look_Image_Height := IH;
      for I in 1 .. IW * IH * 4 loop
         Snap.Quick_Look_Image_Pixels.Append (0);
      end loop;

      Frame := Build_Frame_Commands (Snap, Width, Height, LH);
      for Icon of Frame.Icons loop
         if Icon.Overlay and then Icon.Thumbnail_Width = IW and then Icon.Thumbnail_Height = IH then
            Found := True;
            Assert (Icon.Draw_Width > 0 and then Icon.Draw_Height > 0,
                    "the image preview draws at an explicit size");
            Assert (Icon.Draw_Width /= Icon.Draw_Height,
                    "the image preview draws non-square, preserving the 4:3 aspect");
         end if;
      end loop;
      Assert (Found,
              "the quick look image preview uses the full-resolution image, not the 64px thumbnail");
   end Test_Quick_Look_Image_High_Res;

   --  The palette is theme-aware through Guikit.Draw.Color_For. This is a
   --  legitimate palette assertion (the role-to-color mapping), not a fragile
   --  whole-frame color assertion: the light theme must differ from dark for a
   --  representative role, and high contrast must keep the dark base so its
   --  rendering is not regressed.
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Palette_Color;
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

   procedure Test_Detail_Column_Customization (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Name_Width_Of (Items : Item_Layout_Vectors.Vector) return Natural is
      begin
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               return Cell.Name_Width;
            end if;
         end loop;
         return 0;
      end Name_Width_Of;

      function Size_Width_Of (Items : Item_Layout_Vectors.Vector) return Natural is
      begin
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               return Cell.Size_Width;
            end if;
         end loop;
         return 0;
      end Size_Width_Of;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
      Base_Items : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Base, Layout, Line_Height => 20);
      Base_Name_W : constant Natural := Name_Width_Of (Base_Items);
   begin
      Assert (Base_Name_W > 0, "the name column has a positive width");
      Assert (Size_Width_Of (Base_Items) > 0, "the size column is laid out when visible");

      --  Hiding the size column drops its width to zero and widens the name
      --  column, which must always remain present.
      declare
         Hidden : View_Snapshot := Base;
         Items  : Item_Layout_Vectors.Vector;
      begin
         Hidden.Detail_Columns_Visible (Files.Types.Size_Column) := False;
         Items := Calculate_Item_Layout (Hidden, Layout, Line_Height => 20);
         Assert (Size_Width_Of (Items) = 0, "a hidden column contributes no width");
         Assert (Name_Width_Of (Items) > Base_Name_W,
                 "hiding a column re-flows its width into the remaining columns");
      end;

      --  A custom width is honoured; a sub-minimum request is clamped up.
      declare
         Wide : View_Snapshot := Base;
         Thin : View_Snapshot := Base;
         Wide_Items : Item_Layout_Vectors.Vector;
         Thin_Items : Item_Layout_Vectors.Vector;
      begin
         Wide.Detail_Column_Widths (Files.Types.Size_Column) := 220;
         Thin.Detail_Column_Widths (Files.Types.Size_Column) := 4;
         Wide_Items := Calculate_Item_Layout (Wide, Layout, Line_Height => 20);
         Thin_Items := Calculate_Item_Layout (Thin, Layout, Line_Height => 20);
         Assert (Size_Width_Of (Wide_Items) = 220, "a custom column width drives the layout width");
         Assert (Size_Width_Of (Thin_Items) = Files.Types.Minimum_Detail_Column_Width,
                 "a sub-minimum custom width is clamped up to the minimum");
      end;
   end Test_Detail_Column_Customization;

   --  The column dividers span the visible rows only: they stop at the bottom of
   --  the last on-screen row, never descending past it into empty space below the
   --  list or through the bottom bar.
   procedure Test_Detail_Separators_Within_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Bottom edge (Y + Height) of the tallest column divider, or 0 when none.
      --  Dividers are 1px, border-coloured, and begin at the content top (just
      --  inside the main region), which distinguishes them from the bottom-bar
      --  borders far below.
      function Max_Divider_Bottom
        (Frame : Frame_Commands; Layout : Guikit.Draw.Layout_Metrics) return Natural
      is
         Result : Natural := 0;
      begin
         for Rect of Frame.Rectangles loop
            if Rect.Width = 1 and then Rect.Color = Border_Color
              and then Rect.Y >= Layout.Main_Y and then Rect.Y < Layout.Main_Y + 20
            then
               Result := Natural'Max (Result, Rect.Y + Rect.Height);
            end if;
         end loop;
         return Result;
      end Max_Divider_Bottom;
   begin
      --  Overflow: the last row is off-screen, yet the dividers stop within the
      --  content, never running into the bottom bar.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (40, Files.Types.Details);
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         Bottom   : constant Natural := Max_Divider_Bottom (Frame, Layout);
      begin
         Assert (Bottom > Layout.Main_Y, "the overflowing details view emits column dividers");
         Assert (Bottom <= Layout.Main_Y + Layout.Main_Height,
                 "dividers stay within the content area, not into the bottom bar");
      end;

      --  Short list: the dividers stop exactly at the last visible row's bottom,
      --  well above the content bottom -- not filling the empty space below.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Items    : constant Item_Layout_Vectors.Vector :=
           Calculate_Item_Layout (Snapshot, Layout, 20);
         Last     : constant Item_Layout := Items.Element (Items.Last_Index);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         Bottom   : constant Natural := Max_Divider_Bottom (Frame, Layout);
      begin
         Assert (Bottom = Last.Y + Last.Height,
                 "the divider stops exactly at the last visible row's bottom");
         Assert (Bottom < Layout.Main_Y + Layout.Main_Height,
                 "a short list leaves the dividers well above the content bottom");
      end;
   end Test_Detail_Separators_Within_Content;

   --  Every text element in the bottom bar -- including the view-mode chooser's
   --  segment labels -- sits on a single shared baseline, so nothing looks
   --  vertically off-centre relative to the rest of the bar.
   procedure Test_Bottom_Bar_Text_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      Baseline : Integer := -1;
      Labels   : Natural := 0;
   begin
      for C of Frame.Text loop
         if C.Y >= Bottom_Y then
            if Baseline < 0 then
               Baseline := C.Y;
            else
               Assert (C.Y = Baseline, "all bottom-bar text shares a single vertical baseline");
            end if;
            if To_String (C.Text) = "Small" or else To_String (C.Text) = "Large"
              or else To_String (C.Text) = "Details"
            then
               Labels := Labels + 1;
            end if;
         end if;
      end loop;
      Assert (Baseline >= 0, "the bottom bar draws text");
      Assert (Labels >= 3, "the three view-mode chooser labels are drawn in the bottom bar");
   end Test_Bottom_Bar_Text_Baseline;

   --  The sort button tracks the active field's label width (narrower for a short
   --  field), while the sort dropdown is sized to the widest field so no row clips.
   procedure Test_Sort_Button_Fits_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Name_Bar : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Name, 20);
      Chg_Bar  : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Changed, 20);
      Menu_W   : constant Natural := Files.UI.Sort_Menu_Width (20);
   begin
      Assert (Name_Bar.Sort_Button_Width > 0 and then Chg_Bar.Sort_Button_Width > 0,
              "the sort button is laid out for both fields");
      Assert (Name_Bar.Sort_Button_Width < Chg_Bar.Sort_Button_Width,
              "the sort button is narrower for a shorter field label");
      Assert (Menu_W >= Chg_Bar.Sort_Button_Width,
              "the sort menu is at least as wide as the widest field's button");
      Assert (Menu_W > Name_Bar.Sort_Button_Width,
              "the sort menu is wider than the snug button for a short field");
   end Test_Sort_Button_Fits_Field;

   --  The sort button's content (the field label plus its direction arrow) sits
   --  horizontally centred in the button, not left-aligned against the padding.
   procedure Test_Sort_Label_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
      Frame    : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Name, 20);
      Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      Cell_W   : constant Natural := Natural'Max (1, 20 * 12 / 20);
      Field    : constant String := Files.Localization.Text ("command.sort.name");
      Arrow    : constant String := Files.Localization.Text ("sort.direction.ascending");
      Arrow_W  : constant Natural := Files.UTF8.Display_Units (Arrow) * Cell_W;
      Field_X  : Integer := -1;
      Arrow_X  : Integer := -1;
   begin
      for C of Frame.Text loop
         if C.Y >= Bottom_Y then
            if To_String (C.Text) = Field then
               Field_X := C.X;
            elsif To_String (C.Text) = Arrow then
               Arrow_X := C.X;
            end if;
         end if;
      end loop;
      Assert (Field_X >= 0 and then Arrow_X >= 0, "the sort field label and its arrow are drawn");
      declare
         Left_Gap  : constant Integer := Field_X - Integer (Bar.Sort_Button_X);
         Right_Gap : constant Integer :=
           Integer (Bar.Sort_Button_X + Bar.Sort_Button_Width) - (Arrow_X + Integer (Arrow_W));
      begin
         Assert (abs (Left_Gap - Right_Gap) <= 1,
                 "the sort field label and arrow are centred (equal gaps each side)");
      end;
   end Test_Sort_Label_Centered;

   --  Free space is drawn as its own field (separate from the hidden/visible
   --  counts) with a vertical divider between them in the info region.
   procedure Test_Free_Space_Separate_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
      Vis_Lbl  : constant String := Files.Localization.Text ("status.visible");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Free_Cmd : Boolean := False;
         Counts_Has_Free : Boolean := False;
         Divider  : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), Free_Sfx) > 0 then
                  Free_Cmd := True;
                  --  The free-space command must not also carry the counts text.
                  if Ada.Strings.Fixed.Index (To_String (C.Text), Vis_Lbl) > 0 then
                     Counts_Has_Free := True;
                  end if;
               end if;
            end if;
         end loop;
         --  A 1px vertical divider inside the info region (excludes the view
         --  switcher's own cell dividers, which sit further left), spanning close
         --  to the full bar height.
         for R of Frame.Rectangles loop
            if R.Width = 1 and then R.Color = Border_Color
              and then R.Y >= Bottom_Y and then R.X >= Bar.Info_X
              and then R.X < Bar.Info_X + Bar.Info_Width
            then
               Divider := True;
               Assert (R.Height >= Layout.Bottom_Bar_Height - 2,
                       "the divider spans nearly the full bottom-bar height");
            end if;
         end loop;
         Assert (Free_Cmd, "free space is drawn in the bottom bar");
         Assert (not Counts_Has_Free, "free space is a separate field, not folded into the counts");
         Assert (Divider, "a vertical divider separates the free-space field from the counts");
      end;
   end Test_Free_Space_Separate_Field;

   --  The counts (hidden-files toggle) and the free-space field (free/used
   --  toggle) are both clickable, so their text uses the same active colour as
   --  the info-pane toggle button.
   procedure Test_Counts_Text_Uses_Active_Color (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Vis_Lbl  : constant String := Files.Localization.Text ("status.visible");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Info_Pane_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Counts_C, Free_C, Pane_C : Guikit.Draw.Render_Color;
         Has_Counts, Has_Free, Has_Pane : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), Vis_Lbl) > 0 then
                  Counts_C := C.Color;
                  Has_Counts := True;
               elsif Ada.Strings.Fixed.Index (To_String (C.Text), Free_Sfx) > 0 then
                  Free_C := C.Color;
                  Has_Free := True;
               elsif C.X >= Bar.Info_Pane_X then
                  Pane_C := C.Color;
                  Has_Pane := True;
               end if;
            end if;
         end loop;
         Assert (Has_Counts and then Has_Free and then Has_Pane,
                 "the counts, free-space and info-pane texts are all present");
         Assert (Counts_C = Pane_C,
                 "the counts text uses the same active colour as the info-pane toggle");
         Assert (Counts_C = Free_C,
                 "the clickable free-space field uses the same active colour as the counts");
      end;
   end Test_Counts_Text_Uses_Active_Color;

   --  The counts tooltip spells out what the three numbers mean, so the compact
   --  "N/N/N" form (which drops the labels) stays understandable.
   procedure Test_Counts_Tooltip_Explains_Numbers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Legend : constant String :=
        Files.Localization.Text ("status.hidden") & " / "
        & Files.Localization.Text ("status.visible") & " / "
        & Files.Localization.Text ("status.selected");
   begin
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar   : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Found : Boolean := False;
      begin
         for C of Frame.Tooltips loop
            if C.X = Bar.Info_X and then Ada.Strings.Fixed.Index (To_String (C.Text), Legend) > 0 then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the counts tooltip names the numbers hidden / visible / selected");
      end;
   end Test_Counts_Tooltip_Explains_Numbers;

   --  The free-space field carries its own tooltip, positioned over the field
   --  (right side of the info region), distinct from the toggle's tooltip.
   procedure Test_Free_Space_Has_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Tip_Txt : constant String := Files.Localization.Text ("status.free_space.tooltip");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bar   : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Found : Boolean := False;
      begin
         Assert (Tip_Txt'Length > 0, "the free-space tooltip text is localized");
         for C of Frame.Tooltips loop
            if To_String (C.Text) = Tip_Txt then
               Found := True;
               --  It sits over the free field, in the right half of the info area.
               Assert (C.X >= Bar.Info_X + Bar.Info_Width / 2,
                       "the free-space tooltip covers the field on the right of the info area");
            end if;
         end loop;
         Assert (Found, "the free-space field has its own tooltip");
      end;
   end Test_Free_Space_Has_Tooltip;

   --  The counts (hidden-files toggle) and the free-space field (free/used
   --  toggle) are two separate hover regions: hovering one highlights only it.
   procedure Test_Free_Space_Outside_Toggle_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Command_Enabled (Files.Commands.Toggle_Hidden_Files_Command) := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         HY       : constant Natural := Bottom_Y + Layout.Bottom_Bar_Height / 2;
         Counts_X : constant Natural := Bar.Info_X + 5;
         Free_HX  : constant Natural := Bar.Info_X + Bar.Info_Width - 5;

         --  True when, with the cursor at Hover_At, a hover highlight rectangle
         --  in the bottom bar covers Check_X.
         function Highlight_At (Hover_At, Check_X : Natural) return Boolean is
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snap, 1000, 800, 20, Hover_X => Hover_At, Hover_Y => HY, Has_Hover => True);
         begin
            for R of Frame.Rectangles loop
               if R.Color = Hover_Color and then R.Y >= Bottom_Y
                 and then Check_X >= R.X and then Check_X < R.X + R.Width
               then
                  return True;
               end if;
            end loop;
            return False;
         end Highlight_At;
      begin
         Assert (Highlight_At (Counts_X, Counts_X),
                 "hovering the counts area highlights it");
         Assert (not Highlight_At (Counts_X, Free_HX),
                 "hovering the counts area does not highlight the free-space field");
         Assert (Highlight_At (Free_HX, Free_HX),
                 "hovering the free-space field highlights it");
         Assert (not Highlight_At (Free_HX, Counts_X),
                 "hovering the free-space field does not highlight the counts area");
      end;
   end Test_Free_Space_Outside_Toggle_Hover;

   --  The counts/free geometry split used by both the renderer and the
   --  click hit-test.
   procedure Test_Split_Status_Region (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      TW, DX, FX, FW : Natural;
   begin
      --  No free field: the toggle spans the whole status region.
      Files.UI.Split_Status_Region (200, 300, 0, TW, DX, FX, FW);
      Assert (TW = 300 and then DX = 0 and then FX = 0 and then FW = 0,
              "with no free field the toggle spans the whole info region");

      --  Too narrow for the free field plus divider gaps: no split.
      Files.UI.Split_Status_Region (200, 80, 60, TW, DX, FX, FW);
      Assert (TW = 80 and then FW = 0,
              "a too-narrow region keeps the toggle spanning the whole width");

      --  Room for the free field: carved off on the right, divider one gap left.
      Files.UI.Split_Status_Region (200, 300, 60, TW, DX, FX, FW);
      Assert (FX = 436, "the free field sits right-aligned within the region");
      Assert (DX = 428, "the divider sits one gap left of the free field");
      Assert (TW = 228, "the toggle covers only up to the divider");
      Assert (FW = 64, "the free field box is the label width plus padding");
      Assert (200 + TW = DX and then FX + FW = 200 + 300,
              "toggle, divider gap and free field partition the region");
   end Test_Split_Status_Region;

   --  Clicking the counts area toggles hidden files; clicking the free-space
   --  field toggles between free and used space.
   procedure Test_Free_Space_Click_Toggles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      declare
         Free_W   : constant Natural := Files.Rendering.Free_Space_Label_Width (Snap, 20);
         Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout (1000, Snap.Sort_Field, 20);
         BBP      : constant Natural := Guikit.Layout.Bottom_Bar_Padding;
         Bottom_Y : constant Natural := 800 - (20 + 2 * BBP);
         Y        : constant Natural := Bottom_Y + BBP + 5;
         Counts_X : constant Natural := Bar.Info_X + 5;
         Free_X   : constant Natural := Bar.Info_X + Bar.Info_Width - 5;
      begin
         Assert (Free_W > 0, "the free-space field is present in a wide window");
         Assert
           (Files.UI.Bottom_Bar_Command_At (Counts_X, Y, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Hidden_Files_Command,
            "clicking the counts area toggles hidden files");
         Assert
           (Files.UI.Bottom_Bar_Command_At (Free_X, Y, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Free_Space_Display_Command,
            "clicking the free-space field toggles free/used space");
      end;
   end Test_Free_Space_Click_Toggles;

   --  In used-space mode the field's label shows the used-space suffix, not the
   --  free-space one.
   procedure Test_Used_Space_Label_After_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Used_Sfx : constant String := Files.Localization.Text ("status.used_space.suffix");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Free_Space_Bytes := 12_000_000_000;
      Snap.Total_Space_Bytes := 100_000_000_000;
      Snap.Show_Used_Space := True;
      declare
         Layout    : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame     : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y  : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Has_Used  : Boolean := False;
         Has_Free  : Boolean := False;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Used_Sfx) > 0 then
                  Has_Used := True;
               elsif Ada.Strings.Fixed.Index (To_String (C.Text), " " & Free_Sfx) > 0 then
                  Has_Free := True;
               end if;
            end if;
         end loop;
         Assert (Has_Used, "used-space mode shows the used-space suffix");
         Assert (not Has_Free, "used-space mode does not show the free-space suffix");
      end;
   end Test_Used_Space_Label_After_Toggle;

   --  A wide bar shows the labelled counts; a narrow one drops the labels and
   --  slash-separates the three numbers.
   procedure Test_Counts_Compact_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Vis_Lbl : constant String := Files.Localization.Text ("status.visible");

      function Bottom_Has
        (Frame : Frame_Commands; Layout : Guikit.Draw.Layout_Metrics; Sub : String) return Boolean
      is
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
      begin
         for C of Frame.Text loop
            if C.Y >= Bottom_Y and then Ada.Strings.Fixed.Index (To_String (C.Text), Sub) > 0 then
               return True;
            end if;
         end loop;
         return False;
      end Bottom_Has;
   begin
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      begin
         Assert (Bottom_Has (Frame, Layout, Vis_Lbl), "a wide bar shows the labelled counts");
      end;
      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 600, 800, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 600, 800, 20);
      begin
         Assert (not Bottom_Has (Frame, Layout, Vis_Lbl), "a narrow bar drops the count labels");
         Assert (Bottom_Has (Frame, Layout, "/"), "a narrow bar slash-separates the numbers");
      end;
   end Test_Counts_Compact_When_Narrow;

   procedure Test_Detail_Column_Reorder_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Row_Found : Boolean := False;
      Row       : Item_Layout;

      procedure Locate_Row (Items : Item_Layout_Vectors.Vector) is
      begin
         Row_Found := False;
         for Cell of Items loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Row_Found := True;
               exit;
            end if;
         end loop;
      end Locate_Row;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
   begin
      --  Baseline (enum order): modified precedes size left to right.
      Locate_Row (Calculate_Item_Layout (Base, Layout, Line_Height => 20));
      Assert (Row_Found, "the details list lays out a first data row");
      Assert (Row.Modified_X < Row.Size_X, "the default order lays modified left of size");

      --  Moving size before modified swaps their left-to-right positions while
      --  each column keeps its own width (widths follow the column, not the slot).
      declare
         Reordered : View_Snapshot := Base;
      begin
         Reordered.Detail_Column_Widths (Files.Types.Size_Column) := 150;
         Reordered.Detail_Column_Order :=
           Files.Types.Move_Column (Base.Detail_Column_Order, Files.Types.Size_Column, 2);
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row_Found, "the reordered details list lays out a first data row");
         Assert (Row.Size_X < Row.Modified_X, "the reordered order lays size left of modified");
         Assert (Row.Size_Width = 150, "the customized width follows its column across the reorder");
      end;

      --  A hidden column contributes no width, but re-showing it restores it to
      --  its ordered slot (here: first optional column after the name column).
      declare
         Reordered : View_Snapshot := Base;
      begin
         Reordered.Detail_Column_Order :=
           Files.Types.Move_Column (Base.Detail_Column_Order, Files.Types.Filetype_Column, 2);
         Reordered.Detail_Columns_Visible (Files.Types.Filetype_Column) := False;
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row_Found, "the list lays out a first row with a hidden reordered column");
         Assert (Row.Filetype_Width = 0, "a hidden column contributes no width in its ordered slot");

         Reordered.Detail_Columns_Visible (Files.Types.Filetype_Column) := True;
         Locate_Row (Calculate_Item_Layout (Reordered, Layout, Line_Height => 20));
         Assert (Row.Filetype_Width > 0, "re-showing the column restores its width");
         Assert (Row.Filetype_X < Row.Modified_X and then Row.Filetype_X < Row.Size_X,
                 "the re-shown column reappears in its ordered slot ahead of the others");
      end;
   end Test_Detail_Column_Reorder_Layout;

   procedure Test_Detail_Group_Header_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot;
      Layout   : Guikit.Draw.Layout_Metrics;
      Items    : Item_Layout_Vectors.Vector;
      Header_Center_X : Natural := 0;
      Header_Center_Y : Natural := 0;
      Item_Center_X   : Natural := 0;
      Item_Center_Y   : Natural := 0;
      Header_Rows     : Natural := 0;
   begin
      Snapshot.View_Mode := Files.Types.Details;
      Snapshot.Group_By := Files.Types.Group_By_Type;
      Snapshot.Items.Append
        (Item_Snapshot'
           (Is_Group_Header => True,
            Group_Label     => To_Unbounded_String ("group"),
            Visible_Index   => 0,
            others          => <>));
      Snapshot.Items.Append
        (Item_Snapshot'
           (Name          => To_Unbounded_String ("first"),
            Filetype      => To_Unbounded_String ("text/plain"),
            Kind          => Files.Types.Regular_File_Item,
            Visible_Index => 1,
            others        => <>));
      Snapshot.Items.Append
        (Item_Snapshot'
           (Name          => To_Unbounded_String ("second"),
            Filetype      => To_Unbounded_String ("text/plain"),
            Kind          => Files.Types.Regular_File_Item,
            Visible_Index => 2,
            others        => <>));
      Snapshot.Item_Count    := 2;
      Snapshot.Visible_Count := 2;

      Layout := Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Items  := Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);

      Assert (Natural (Items.Length) = 3, "each snapshot row, header included, is laid out");
      for Cell of Items loop
         if Cell.Visible_Index = 0 then
            Header_Rows := Header_Rows + 1;
            Header_Center_X := Cell.X + Cell.Width / 2;
            Header_Center_Y := Cell.Y + Cell.Height / 2;
         elsif Cell.Visible_Index = 1 then
            Item_Center_X := Cell.X + Cell.Width / 2;
            Item_Center_Y := Cell.Y + Cell.Height / 2;
         end if;
      end loop;

      Assert (Header_Rows = 1, "the grouping band emits exactly one header row");
      Assert (Item_At (Items, Header_Center_X, Header_Center_Y) = 0,
              "clicking a group header row selects nothing");
      Assert (Item_At (Items, Item_Center_X, Item_Center_Y) = 1,
              "clicking a real row under a header still resolves to that item");
   end Test_Detail_Group_Header_Rows;

   procedure Test_Detail_Header_Separator_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;

      Base   : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Layout : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Base, Width => 1000, Height => 800, Line_Height => 20);
      Items  : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Base, Layout, Line_Height => 20);

      Row      : Item_Layout;
      Found    : Boolean := False;
      Header_Y : Natural;
   begin
      --  Column boundaries align between the header and the item rows, so a data
      --  row's per-column left edges give the exact separator x positions.
      for Cell of Items loop
         if Cell.Visible_Index = 1 then
            Row := Cell;
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "the details list lays out a first data row");

      --  A y between the pane top and the first row lands inside the header band.
      Header_Y := (Layout.Main_Y + Row.Y) / 2;

      declare
         At_Size : constant Detail_Column_Separator :=
           Details_Header_Separator_At (Base, Layout, Row.Size_X, Header_Y, Line_Height => 20);
         At_Modified : constant Detail_Column_Separator :=
           Details_Header_Separator_At (Base, Layout, Row.Modified_X, Header_Y, Line_Height => 20);
         Mid_Name : constant Detail_Column_Separator :=
           Details_Header_Separator_At
             (Base, Layout, Row.Name_X + Row.Name_Width / 2, Header_Y, Line_Height => 20);
         Above_Header : constant Detail_Column_Separator :=
           Details_Header_Separator_At (Base, Layout, Row.Size_X, Row.Y + Row.Height, Line_Height => 20);
      begin
         Assert (At_Size.Present and then At_Size.Column = Files.Types.Size_Column,
                 "a press on the size column's left edge resolves to the size separator");
         Assert (At_Size.Origin_X = Row.Size_X and then At_Size.Width = Row.Size_Width,
                 "the separator reports the column's edge and current width");
         Assert (At_Modified.Present and then At_Modified.Column = Files.Types.Modified_Column,
                 "the boundary between name and the first fixed column resizes that fixed column");
         Assert (not Mid_Name.Present,
                 "a press in the middle of a header cell is not a separator");
         Assert (not Above_Header.Present,
                 "a press below the header band is not a separator");
      end;
   end Test_Detail_Header_Separator_Hit_Test;

   procedure Test_Favorite_Star_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Star glyphs are symbols emitted from source, not the catalog; rebuild
      --  their UTF-8 here so the assertions match what the frame carries.
      Filled_Star : constant String :=
        Character'Val (16#E2#) & Character'Val (16#98#) & Character'Val (16#85#);
      Toolbar : constant Guikit.Layout.Toolbar_Layout :=
        Guikit.Layout.Calculate_Toolbar_Layout (1000);

      function Count_Filled_Gold (Frame : Frame_Commands) return Natural is
         Total : Natural := 0;
      begin
         for Cmd of Frame.Text loop
            if To_String (Cmd.Text) = Filled_Star
              and then Cmd.Color = Guikit.Draw.Favorite_Star_Color
            then
               Total := Total + 1;
            end if;
         end loop;
         return Total;
      end Count_Filled_Gold;

      --  The path-bar favourite indicator is a drawn vector shape: a filled
      --  star (gold triangles) when favourited, an outline (muted triangles)
      --  when not. Detect it by colour within the star's band -- the top
      --  toolbar row at the very start of the path bar (Middle section).
      function Star_Triangle_Present
        (Frame : Frame_Commands;
         Color : Guikit.Draw.Render_Color)
         return Boolean
      is
         Left  : constant Float := Float (Toolbar.Middle_X);
         Right : constant Float := Float (Toolbar.Middle_X) + 80.0;
      begin
         for Tri of Frame.Triangles loop
            if Tri.Color = Color
              and then Tri.Y1 <= 45.0 and then Tri.Y2 <= 45.0 and then Tri.Y3 <= 45.0
              and then Tri.X1 >= Left and then Tri.X1 <= Right
            then
               return True;
            end if;
         end loop;
         return False;
      end Star_Triangle_Present;
   begin
      --  Grid indicator: exactly the favorited items carry a gold filled star.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Is_Favorite := True;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Assert
              (Count_Filled_Gold (Frame) = 1,
               "one favorited grid item draws exactly one gold filled star");
         end;
      end;

      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         Assert
           (Count_Filled_Gold (Frame) = 0,
            "no favorited items means no gold filled grid star in details view");
      end;

      --  Path-bar toggle: with no items in the view, the only star is the path
      --  star, so its filled/outline shape reflects the current-dir state.
      declare
         Fav      : View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      begin
         Fav.Current_Path := To_Unbounded_String ("/tmp/starred");
         Fav.Current_Path_Is_Favorite := True;
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Fav, 1000, 800, 20);
         begin
            Assert
              (Star_Triangle_Present (Frame, Guikit.Draw.Favorite_Star_Color),
               "a favorited current directory draws the filled path star");
            Assert
              (not Star_Triangle_Present (Frame, Guikit.Draw.Muted_Text_Color),
               "the favorited path bar does not also draw the empty outline star");
         end;
      end;

      declare
         Plain : View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      begin
         Plain.Current_Path := To_Unbounded_String ("/tmp/plain");
         Plain.Current_Path_Is_Favorite := False;
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Plain, 1000, 800, 20);
         begin
            Assert
              (Star_Triangle_Present (Frame, Guikit.Draw.Muted_Text_Color),
               "a non-favorited current directory draws the empty outline path star");
            Assert
              (not Star_Triangle_Present (Frame, Guikit.Draw.Favorite_Star_Color),
               "a non-favorited current directory draws no filled star");
         end;
      end;
   end Test_Favorite_Star_Indicators;

   procedure Test_Color_Label_Grid_Dots (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      --  A labeled item emits a filled rectangle in its label color.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Label := Files.Types.Green;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Assert
              (Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Green)),
               "a green-labeled item draws a green corner dot");
            Assert
              (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Red)),
               "the green-labeled item draws no red dot");
         end;
      end;

      --  An unlabeled grid draws no label dot in any label color.
      declare
         Snapshot : constant View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         Assert
           (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Green)),
            "an unlabeled grid draws no green dot");
         Assert
           (not Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Blue)),
            "an unlabeled grid draws no blue dot");
      end;

      --  Different labels resolve to different dot colors.
      declare
         Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
         First    : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         First.Label := Files.Types.Purple;
         Snapshot.Items.Replace_Element (1, First);
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, 1000, 800, 20);
         begin
            Assert
              (Has_Rectangle_Colored (Frame, Files.Rendering.Label_Render_Color (Files.Types.Purple)),
               "a purple-labeled item draws a purple dot");
            Assert
              (Files.Rendering.Label_Render_Color (Files.Types.Purple)
                 /= Files.Rendering.Label_Render_Color (Files.Types.Green),
               "distinct labels resolve to distinct dot colors");
         end;
      end;
   end Test_Color_Label_Grid_Dots;

   procedure Test_Marquee_Items_In_Rect (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout   : constant Guikit.Draw.Layout_Metrics :=
        Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Items    : constant Item_Layout_Vectors.Vector :=
        Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);

      --  True when Hits contains exactly the ascending indices in Expected.
      function Exactly
        (Hits     : Visible_Index_Vectors.Vector;
         Expected : Visible_Index_Vectors.Vector)
         return Boolean is
      begin
         if Natural (Hits.Length) /= Natural (Expected.Length) then
            return False;
         end if;
         for Offset in 0 .. Natural (Expected.Length) - 1 loop
            if Hits.Element (Hits.First_Index + Offset)
              /= Expected.Element (Expected.First_Index + Offset)
            then
               return False;
            end if;
         end loop;
         return True;
      end Exactly;

      Cell_1 : constant Item_Layout := Items.Element (1);
      Cell_2 : constant Item_Layout := Items.Element (2);
      Rect_X : Natural;
      Rect_Y : Natural;
      Rect_W : Natural;
      Rect_H : Natural;
      Two    : Visible_Index_Vectors.Vector;
   begin
      Assert (Natural (Items.Length) = 6, "the sample list lays out every item");

      Two.Append (1);
      Two.Append (2);

      --  A rectangle from inside cell 1 to inside cell 2 touches exactly those
      --  two cells (details rows stack vertically, so 1 and 2 are adjacent).
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Items_In_Rect
             (Items,
              X      => Cell_1.X + Cell_1.Width / 2,
              Y      => Cell_1.Y + Cell_1.Height / 2,
              Width  => 1,
              Height => (Cell_2.Y + Cell_2.Height / 2) - (Cell_1.Y + Cell_1.Height / 2));
      begin
         Assert (Exactly (Hits, Two), "a rect spanning two cells returns exactly those two indices");
      end;

      --  Partial overlap counts as a hit: a one-pixel rectangle sitting on the
      --  top edge of cell 1 still touches it.
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Items_In_Rect (Items, Cell_1.X + 1, Cell_1.Y, Width => 1, Height => 1);
      begin
         Assert (Natural (Hits.Length) = 1 and then Hits.First_Element = 1,
                 "a rectangle grazing a cell edge counts as a hit");
      end;

      --  Empty space well below every laid-out row touches nothing.
      declare
         Bottom : constant Natural := Layout.Main_Y + Layout.Main_Height;
         Hits   : constant Visible_Index_Vectors.Vector :=
           Items_In_Rect (Items, Layout.Main_X, Bottom + 100, Width => 20, Height => 20);
      begin
         Assert (Hits.Is_Empty, "a rect over empty space below the grid returns no items");
      end;

      --  A zero-area rectangle (a plain click, no drag) touches nothing.
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Items_In_Rect (Items, Cell_1.X, Cell_1.Y, Width => 0, Height => 0);
      begin
         Assert (Hits.Is_Empty, "a zero-area marquee selects nothing (a plain click)");
      end;

      --  Normalization: details rows share an X, so a marquee spanning rows 1
      --  and 2 needs a nonzero width. Drag from a lower-right corner in row 2 up
      --  to an upper-left corner in row 1; the normalized rectangle (and hence
      --  its hits) must match the equivalent down-right drag over the same span.
      Marquee_Rect
        (Start_X   => Cell_2.X + 15,
         Start_Y   => Cell_2.Y + Cell_2.Height / 2,
         Current_X => Cell_1.X + 5,
         Current_Y => Cell_1.Y + Cell_1.Height / 2,
         X         => Rect_X,
         Y         => Rect_Y,
         Width     => Rect_W,
         Height    => Rect_H);
      Assert (Rect_X = Cell_1.X + 5, "up-left drag normalizes X to the min corner");
      Assert (Rect_Y = Cell_1.Y + Cell_1.Height / 2, "up-left drag normalizes Y to the min corner");
      Assert (Rect_W = 10, "the normalized width is the corner x distance");
      declare
         Hits : constant Visible_Index_Vectors.Vector :=
           Items_In_Rect (Items, Rect_X, Rect_Y, Rect_W, Rect_H);
      begin
         Assert (Exactly (Hits, Two), "an up-left drag selects the same two cells as down-right");
      end;
   end Test_Marquee_Items_In_Rect;

   procedure Test_Marquee_Frame_Draws_Rectangle (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      Idle     : constant Frame_Commands :=
        Build_Frame_Commands (Snapshot, 1000, 800, 20);
      Active   : constant Frame_Commands :=
        Build_Frame_Commands
          (Snapshot, 1000, 800, 20,
           Marquee_Active => True,
           Marquee_X      => 100,
           Marquee_Y      => 120,
           Marquee_W      => 200,
           Marquee_H      => 150);
   begin
      Assert (not Has_Rectangle_Colored (Idle, Marquee_Color),
              "no marquee rectangle is drawn while the marquee is inactive");
      Assert (Has_Rectangle_Colored (Active, Marquee_Color),
              "an active marquee draws a translucent marquee-colored fill over the grid");
   end Test_Marquee_Frame_Draws_Rectangle;

end Files_Suite.Rendering;
