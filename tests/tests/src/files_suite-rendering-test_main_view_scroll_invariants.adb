separate (Files_Suite.Rendering)
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
            Files_Suite.Support.Assert_Equal
              (MV_Top.Scrollbar_Thumb_Y,
               MV_Top.Scrollbar_Y,
               "at the top the thumb sits exactly at the track top");
            Files_Suite.Support.Assert_Equal
              (MV_Bot.Scrollbar_Thumb_Y + MV_Bot.Scrollbar_Height,
               MV_Bot.Scrollbar_Y + MV_Bot.Scrollbar_Track_Height,
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
