with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with System;

with Files.Commands;
with Files.Breadcrumbs;
with Files.Events;
with Files.Extension_Labels;
with Files.File_System;
with Files.Fonts;
with Files.Folder_Tree;
with Files.Localization;
with Files.Model;
with Files.UI;
with Files.UTF8;
with Files.Quick_Look;
with Guikit.Draw;
with Files.Rendering;
with Files.Accessibility;
with Files.Settings;
with Files_Suite.Support;
with A11y.Platforms;
with A11y.Results;
with A11ykit.Compatibility;
with A11ykit.Provider;
with A11ykit.Tree;
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
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.Rendering.Context_Menu_Row_Kind;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Types.Focus_Target;
   use type A11y.Platforms.Platform_Kind;
   use type A11y.Results.Status_Code;
   use type System.Address;

   type Rendering_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Rendering_Test_Case);

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Main_View_Scroll_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Command_Palette_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Frame_Rendering_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compact_Frame_Commands_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compact_Overlay_Commands_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extreme_Size_Saturation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Extension_Label_Extreme_Height (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Large_Icons_Rename_Caret (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Large_Icon_Badges_Bounded (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Multi_Rename_Fields_And_Carets (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Show_Extensions_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_Click_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Emoji_Draws_As_Colour_Icons (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Modified_Time_Is_Local (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_A11ykit_Tree_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlay_Suppresses_Background_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Uses_Shadow_Color (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Has_Modal_Backdrop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Input_Scroll_Keeps_Caret_Visible (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Floating_Menus_Have_Elevation (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Space_Bar_Renders (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Counts_Compact_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Column_Reorder_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Favorite_Star_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Color_Label_Grid_Dots (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Items_In_Rect (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Auto_Scroll_Step (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Marquee_Frame_Draws_Rectangle (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Drag_Preview_Uses_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Details_Header_Text_Centered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Toolbar_Text_Optically_Centered (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compact_Breadcrumbs_Stay_In_Field (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compact_Empty_State_Stays_In_View (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Empty_Info_Pane_Message (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_Pane_Content_Clipped (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scope_Chip_Has_Own_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Filetype_Labels_Omit_Document (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Overlay_Content (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Quick_Look_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Label_Picker_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class);
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
        (T, Test_Compact_Frame_Commands_Bounded'Access,
         "compact frame commands have positive framebuffer-bounded geometry");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compact_Overlay_Commands_Bounded'Access,
         "compact overlay commands and hit regions stay inside the framebuffer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extreme_Size_Saturation'Access, "layout saturates at extreme sizes without overflow");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Extension_Label_Extreme_Height'Access,
         "extension labels reject an impossible raster height without raising");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Large_Icons_Rename_Caret'Access,
         "large-icons rename edits left-aligned across the cell with the caret in the label region");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Large_Icon_Badges_Bounded'Access,
         "large-icon extension badges stay inside the main viewport");
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
        (T, Test_Emoji_Draws_As_Colour_Icons'Access,
         "an emoji becomes a colour icon in both the main and overlay layers");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Hidden_Count'Access, "bottom bar reflects the hidden count and exposes a toggle button");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Free_Space'Access,
         "bottom bar shows filesystem free space when known and omits it when unknown");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Modified_Time_Is_Local'Access, "the Modified column shows local time, not UTC");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_A11ykit_Tree_Mapping'Access,
         "a frame's accessibility nodes map into a well-formed hierarchical a11ykit tree");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Bottom_Bar_Selection_Summary'Access,
         "bottom bar shows the selection count and summed size when items are selected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Suppresses_Item_Hover'Access,
         "an open context menu suppresses the main-grid item hover highlight");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Overlay_Suppresses_Background_Tooltips'Access,
         "an open overlay suppresses tooltips from controls behind it");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Root_Selector_Uses_Shadow_Color'Access,
         "the root selector uses the theme's translucent shadow role");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Conflict_Has_Modal_Backdrop'Access,
         "the modal paste-conflict dialog dims the inactive file view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Input_Scroll_Keeps_Caret_Visible'Access,
         "a focused input scrolls just far enough to keep its caret visible");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tooltip_Wraps_When_Narrow'Access,
         "a narrow window wraps a long tooltip onto multiple rows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Menu_Separators'Access,
         "the item context menu groups its commands with non-selectable separators");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Floating_Menus_Have_Elevation'Access,
         "context and sort menus use the shared overlay surface and shadow");
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
        (T, Test_Label_Picker_Drawn_In_Overlay'Access,
         "the label picker composites in the overlay layer, not beneath file icons");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Theme_Palette_Selection'Access,
         "light and high-contrast palettes are visually distinct from dark");
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
        (T, Test_Space_Bar_Renders'Access,
         "bar mode draws a track with a blue used-fraction core and no text");
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
        (T, Test_Marquee_Auto_Scroll_Step'Access,
         "a marquee drag past the rows region auto-scrolls, accelerating with distance and capped");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Marquee_Frame_Draws_Rectangle'Access,
         "an active marquee draws a translucent selection rectangle over the grid");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Drag_Preview_Uses_Overlay'Access,
         "the drag preview is a bounded overlay above file-view content");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Toolbar_Text_Optically_Centered'Access,
         "toolbar input text aligns vertically with the toolbar icons and star");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compact_Breadcrumbs_Stay_In_Field'Access,
         "compact breadcrumbs stay inside the path field");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compact_Empty_State_Stays_In_View'Access,
         "compact empty-state content stays inside the main view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Empty_Info_Pane_Message'Access,
         "an open information pane explains an empty selection");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Info_Pane_Content_Clipped'Access,
         "information-pane content stays above the bottom bar at compact heights");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scope_Chip_Has_Own_Tooltip'Access,
         "the search-scope chip has its own tooltip describing the scope");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Filetype_Labels_Omit_Document'Access,
         "detail type labels omit the redundant 'document' word");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Details_Header_Text_Centered'Access,
         "details header labels are optically centred like the bottom-bar text");
   end Register_Tests;

   --  Build a deterministic snapshot with Count regular-file items in Mode.
   --  Rectangles in Guikit.Widgets.Draw_Drop_Shadow: four bands, each a
   --  strip below the panel and one beside it.
   Shadow_Rectangles : constant := 8;

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

   --  The toolbar input text is optically centred in its field the same way as
   --  the (accepted) bottom-bar text, so it lines up vertically with the
   --  geometric-centred toolbar icons and favourite star.
   procedure Test_Toolbar_Text_Optically_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap        : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Frame       : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
      Layout      : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
      Toolbar_Top : constant Natural := Guikit.Layout.Toolbar_Input_Y (20);
      Field_H     : constant Natural := Guikit.Layout.Toolbar_Input_Height (20);
      Field_Ctr   : constant Natural := Toolbar_Top + Field_H / 2;
      Bottom_Top  : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;

      Toolbar_Text_Y : Integer := -1;
      Bottom_Text_Y  : Integer := -1;
      Icon_Center    : Integer := -1;
   begin
      for C of Frame.Text loop
         if C.Y >= Toolbar_Top and then C.Y < Layout.Toolbar_Height
           and then (Toolbar_Text_Y < 0 or else C.Y < Toolbar_Text_Y)
         then
            Toolbar_Text_Y := C.Y;
         elsif C.Y >= Bottom_Top and then (Bottom_Text_Y < 0 or else C.Y < Bottom_Text_Y) then
            Bottom_Text_Y := C.Y;
         end if;
      end loop;
      for I of Frame.Icons loop
         if I.Y < Layout.Toolbar_Height and then Icon_Center < 0 then
            Icon_Center := I.Y + I.Size / 2;
         end if;
      end loop;
      Assert (Toolbar_Text_Y >= 0 and then Bottom_Text_Y >= 0 and then Icon_Center >= 0,
              "a toolbar text, a bottom-bar text and a toolbar icon are all present");
      --  Text: same optical offset within its field as the bottom-bar text.
      Assert (Toolbar_Text_Y - Toolbar_Top = Bottom_Text_Y - Bottom_Top,
              "toolbar text uses the same optical centring as the bottom-bar text");
      --  Icons: geometrically centred in the toolbar field (within rounding).
      Assert (abs (Icon_Center - Field_Ctr) <= 1,
              "the toolbar icon is centred in the toolbar field");
   end Test_Toolbar_Text_Optically_Centered;

   procedure Test_Compact_Breadcrumbs_Stay_In_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width   : constant Natural := 640;
      Snap    : View_Snapshot := Sample_Snapshot (0, Files.Types.Details);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Margin  : constant Natural := 6;
      End_X   : constant Natural :=
        Toolbar.Middle_X + Toolbar.Middle_Width - Natural'Min (Margin, Toolbar.Middle_Width);
   begin
      Snap.Breadcrumb_Segments :=
        Files.Breadcrumbs.Segments ("/home/example/projects/ada/files");
      declare
         Rows : constant Breadcrumb_Segment_Layout_Vectors.Vector :=
           Calculate_Breadcrumb_Layout (Snap, Width, 20);
      begin
         Assert (not Rows.Is_Empty, "a compact path still shows its current directory");
         for Row of Rows loop
            Assert
              (Row.X <= End_X and then Row.Width <= End_X - Row.X,
               "every compact breadcrumb remains inside the path field");
         end loop;
      end;
   end Test_Compact_Breadcrumbs_Stay_In_Field;

   procedure Test_Compact_Empty_State_Stays_In_View
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      LH      : constant Positive := 20;
      Height  : constant Natural :=
        3 * LH + 2 * Guikit.Layout.Bottom_Bar_Padding + 1;
      Snap    : constant View_Snapshot := Sample_Snapshot (0, Files.Types.Small_Icons);
      Found   : Boolean := False;
   begin
      for Width in 1 .. 120 loop
         declare
            Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snap, Width, Height, LH);
            Frame  : constant Frame_Commands :=
              Build_Frame_Commands (Snap, Width, Height, LH);
         begin
            Assert (Layout.Main_Height = 1, "the compact case has a one-pixel main view");
            for Command of Frame.Text loop
               if Command.Y >= Layout.Main_Y
                 and then Command.Y < Layout.Main_Y + Layout.Main_Height
               then
                  Found := True;
                  Assert
                    (Command.X >= Layout.Main_X
                     and then Command.X + Command.Width <= Layout.Main_X + Layout.Main_Width
                     and then Command.Y >= Layout.Main_Y
                     and then Command.Y + Command.Height <= Layout.Main_Y + Layout.Main_Height,
                     "empty-state text stays inside the compact main view");
               end if;
            end loop;
         end;
      end loop;
      Assert (Found, "the compact cases exercise visible empty-state text");
   end Test_Compact_Empty_State_Stays_In_View;

   procedure Test_Empty_Info_Pane_Message (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
      Message : constant String := Files.Localization.Text ("error.selection.empty");
      Found   : Boolean := False;
   begin
      Snap.Info_Pane_Open := True;
      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 640, 480, 20);
      begin
         for Command of Frame.Text loop
            if To_String (Command.Text) = Message then
               Found := True;
            end if;
         end loop;
      end;
      Assert (Found, "the empty information pane renders its localized empty-selection message");
   end Test_Empty_Info_Pane_Message;

   procedure Test_Info_Pane_Content_Clipped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width         : constant Natural := 640;
      LH            : constant Positive := 20;
      Found_Clipped : Boolean := False;
      Sample_Info   : Info_Snapshot;
   begin
      Sample_Info.Name := To_Unbounded_String ("compact.txt");
      Sample_Info.Filetype := To_Unbounded_String ("text/plain");
      Sample_Info.Size_Available := True;
      Sample_Info.Size := 1_024;
      Sample_Info.Mode_Available := True;
      Sample_Info.Mode_Bits := 8#640#;
      Sample_Info.Ownership_Available := True;
      Sample_Info.Owner_Name := To_Unbounded_String ("owner");
      Sample_Info.Group_Name := To_Unbounded_String ("group");
      Sample_Info.Filetype_Extra := To_Unbounded_String ("compact metadata");

      for Selection_Count in 0 .. 2 loop
         declare
            Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);
         begin
            Snap.Info_Pane_Open := True;
            Snap.Permissions_Editable := True;
            Snap.Ownership_Editable := True;
            Snap.Info_Pane_Scroll_Lines :=
              (if Selection_Count = 1 then 19 elsif Selection_Count = 2 then 2 else 0);
            for Index in 1 .. Selection_Count loop
               Sample_Info.Name := To_Unbounded_String ("compact" & Integer'Image (Index) & ".txt");
               Snap.Selected_Info.Append (Sample_Info);
            end loop;

            for Height in 90 .. 150 loop
               declare
                  Layout : constant Guikit.Draw.Layout_Metrics :=
                    Calculate_Layout (Snap, Width, Height, LH);
                  Info   : constant Info_Pane_Layout :=
                    Calculate_Info_Pane_Layout (Snap, Layout, LH);
                  Frame  : constant Frame_Commands :=
                    Build_Frame_Commands (Snap, Width, Height, LH);
                  Right  : constant Natural := Info.X + Info.Width;
                  Bottom : constant Natural := Info.Y + Info.Height;
               begin
                  for Command of Frame.Text loop
                     if Command.X >= Info.X and then Command.X < Right
                       and then Command.Y >= Info.Y and then Command.Y < Bottom
                     then
                        Assert
                          (Command.Height <= Bottom - Command.Y,
                           "information-pane text stays above the bottom bar");
                        Found_Clipped := Found_Clipped or else Command.Height < LH;
                     end if;
                  end loop;

                  for Tip of Frame.Tooltips loop
                     if Tip.X >= Info.X and then Tip.X < Right
                       and then Tip.Y >= Info.Y and then Tip.Y < Bottom
                     then
                        Assert
                          (Tip.Height <= Bottom - Tip.Y,
                           "information-pane tooltip regions stay inside the pane");
                     end if;
                  end loop;

                  for Node of Frame.Accessibility loop
                     if Node.X >= Info.X and then Node.X < Right
                       and then (Node.Role = Role_Pane or else Node.Role = Role_List_Item)
                     then
                        Assert
                          (Node.Y >= Info.Y
                           and then Node.Y <= Bottom
                           and then Node.Height <= Bottom - Node.Y,
                           "information-pane accessibility nodes stay inside the pane");
                     end if;
                  end loop;

                  for Hit of Frame.Permission_Hits loop
                     Assert
                       (Hit.Y >= Info.Y
                        and then Hit.Y <= Bottom
                        and then Hit.Height <= Bottom - Hit.Y,
                        "permission hit regions stay inside the information pane");
                  end loop;
                  for Hit of Frame.Ownership_Hits loop
                     Assert
                       (Hit.Y >= Info.Y
                        and then Hit.Y <= Bottom
                        and then Hit.Height <= Bottom - Hit.Y,
                        "ownership hit regions stay inside the information pane");
                  end loop;
               end;
            end loop;
         end;
      end loop;

      Assert (Found_Clipped, "the compact-height cases exercise a partially visible metadata row");
   end Test_Info_Pane_Content_Clipped;

   --  Hovering the search-scope chip shows a tooltip describing the scope, not
   --  the filter field's tooltip that spans the same toolbar section.
   procedure Test_Scope_Chip_Has_Own_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap  : constant View_Snapshot := Sample_Snapshot (5, Files.Types.Small_Icons);
      Tip   : constant String := Files.Localization.Text ("search.scope.tooltip");
      Frame : constant Frame_Commands := Build_Frame_Commands (Snap, 1400, 800, 20);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (1400);
      Chip  : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Files.UI.Filter_Scope_Chip_Width (20), 20);
      Found : Boolean := False;
   begin
      Assert (Chip.Visible, "the search-scope chip is visible in a wide window");
      Assert (Tip'Length > 0, "the scope tooltip text is localized");
      declare
         CX : constant Natural := Chip.X + Chip.Width / 2;
         CY : constant Natural := Chip.Y + Chip.Height / 2;
      begin
         for C of Frame.Tooltips loop
            if CX >= C.X and then CX < C.X + C.Width
              and then CY >= C.Y and then CY < C.Y + C.Height
            then
               --  First tooltip covering the point wins, as Tooltip_At resolves it.
               Assert (To_String (C.Text) = Tip,
                       "the first tooltip over the scope chip describes the scope");
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "a tooltip covers the scope chip");
      end;
   end Test_Scope_Chip_Has_Own_Tooltip;

   --  The detail-view type labels are the short format names, without the
   --  redundant "document" word that widened the Type column.
   procedure Test_Filetype_Labels_Omit_Document (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Files.Localization.Text ("info.kind.markdown") = "Markdown",
              "the markdown type label omits 'document'");
      Assert (Files.Localization.Text ("info.kind.document.pdf") = "PDF",
              "the PDF type label omits 'document'");
      Assert (Files.Localization.Text ("info.kind.document.word") = "Word",
              "the Word type label omits 'document'");
      Assert (Files.Localization.Text ("info.kind.document.spreadsheet")'Length > 0,
              "the spreadsheet type label is present");
   end Test_Filetype_Labels_Omit_Document;

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
        [Files.Types.Small_Icons, Files.Types.Large_Icons, Files.Types.Details];
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

   procedure Test_Compact_Frame_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths  : constant array (Positive range <>) of Natural :=
        [0, 1, 7, 40, 119, 279, 280, 639, 640];
      Heights : constant array (Positive range <>) of Natural :=
        [0, 1, 7, 8, 9, 20, 39, 40, 41, 72, 73, 100];
      Snap    : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
   begin
      --  Exercise both the filled-star triangles and the toolbar asset icons.
      Snap.Current_Path_Is_Favorite := True;
      for Width of Widths loop
         for Height of Heights loop
            declare
               Frame : constant Frame_Commands :=
                 Build_Frame_Commands (Snap, Width, Height, 20);
            begin
               for Command of Frame.Rectangles loop
                  Assert
                    (Command.Width > 0 and then Command.Height > 0
                     and then Command.X + Command.Width <= Width
                     and then Command.Y + Command.Height <= Height,
                     "rectangle commands stay inside the compact framebuffer");
               end loop;
               for Command of Frame.Text loop
                  Assert
                    (Command.Width > 0 and then Command.Height > 0
                     and then Command.X + Command.Width <= Width
                     and then Command.Y + Command.Height <= Height,
                     "text commands stay inside the compact framebuffer");
               end loop;
               for Tip of Frame.Tooltips loop
                  Assert
                    (Tip.Width > 0 and then Tip.Height > 0
                     and then Tip.X + Tip.Width <= Width
                     and then Tip.Y + Tip.Height <= Height,
                     "tooltip regions stay inside the compact framebuffer");
               end loop;
               for Node of Frame.Accessibility loop
                  Assert
                    (Node.Width > 0 and then Node.Height > 0
                     and then Node.X + Node.Width <= Width
                     and then Node.Y + Node.Height <= Height,
                     "accessibility nodes stay inside the compact framebuffer");
               end loop;
               for Icon of Frame.Icons loop
                  declare
                     Draw_W : constant Natural :=
                       (if Icon.Draw_Width > 0 then Icon.Draw_Width else Icon.Size);
                     Draw_H : constant Natural :=
                       (if Icon.Draw_Height > 0 then Icon.Draw_Height else Icon.Size);
                  begin
                     Assert
                       (Draw_W > 0 and then Draw_H > 0
                        and then Icon.X + Draw_W <= Width
                        and then Icon.Y + Draw_H <= Height,
                        "icon commands stay inside the compact framebuffer");
                  end;
               end loop;
               for Triangle of Frame.Triangles loop
                  Assert
                    (Triangle.X1 >= 0.0 and then Triangle.X1 <= Float (Width)
                     and then Triangle.X2 >= 0.0 and then Triangle.X2 <= Float (Width)
                     and then Triangle.X3 >= 0.0 and then Triangle.X3 <= Float (Width)
                     and then Triangle.Y1 >= 0.0 and then Triangle.Y1 <= Float (Height)
                     and then Triangle.Y2 >= 0.0 and then Triangle.Y2 <= Float (Height)
                     and then Triangle.Y3 >= 0.0 and then Triangle.Y3 <= Float (Height),
                     "triangle commands stay inside the compact framebuffer");
               end loop;
            end;
         end loop;
      end loop;
   end Test_Compact_Frame_Commands_Bounded;

   procedure Test_Compact_Overlay_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths  : constant array (Positive range <>) of Natural :=
        [0, 1, 5, 20, 80, 279, 360, 640];
      Heights : constant array (Positive range <>) of Natural :=
        [0, 1, 2, 20, 72, 100, 200];
   begin
      for Scenario in 1 .. 10 loop
         declare
            Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         begin
            Snap.Command_Enabled := [others => True];
            case Scenario is
               when 1 =>
                  Snap.Paste_Conflict_Open := True;
                  Snap.Paste_Conflict_Name := To_Unbounded_String ("conflict.txt");
               when 2 =>
                  Snap.Paste_Progress_Open := True;
                  Snap.Paste_Progress_Done := 1;
                  Snap.Paste_Progress_Total := 2;
                  Snap.Paste_Progress_Name := To_Unbounded_String ("copy.txt");
               when 3 =>
                  Snap.Quick_Look_Open := True;
                  Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
                  Snap.Quick_Look_Name := To_Unbounded_String ("preview.txt");
               when 4 =>
                  Snap.Label_Picker_Open := True;
               when 5 =>
                  Snap.Sort_Menu_Open := True;
               when 6 =>
                  Snap.Command_Palette_Open := True;
               when 7 =>
                  Snap.Settings_Pane_Open := True;
               when 8 =>
                  Snap.Context_Menu_Open := True;
                  Snap.Context_Menu_Target := Files.Model.Context_Menu_Item;
                  Snap.Context_Menu_X := 10;
                  Snap.Context_Menu_Y := 10;
               when 9 =>
                  Snap.Root_Selector_Open := True;
                  Snap.Root_Selected_Index := 1;
                  Snap.Root_Paths.Append (To_Unbounded_String ("/"));
                  Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));
               when others =>
                  Snap.Tree_Panel_Open := True;
            end case;

            for Width of Widths loop
               for Height of Heights loop
                  declare
                     Frame : constant Frame_Commands :=
                       Build_Frame_Commands (Snap, Width, Height, 20);
                  begin
                     for Command of Frame.Overlay_Rectangles loop
                        Assert
                          (Command.Width > 0 and then Command.Height > 0
                           and then Command.X + Command.Width <= Width
                           and then Command.Y + Command.Height <= Height,
                           "overlay rectangles stay inside the compact framebuffer");
                     end loop;
                     for Command of Frame.Overlay_Text loop
                        Assert
                          (Command.Width > 0 and then Command.Height > 0
                           and then Command.X + Command.Width <= Width
                           and then Command.Y + Command.Height <= Height,
                           "overlay text stays inside the compact framebuffer");
                     end loop;
                     for Node of Frame.Accessibility loop
                        Assert
                          (Node.Width > 0 and then Node.Height > 0
                           and then Node.X + Node.Width <= Width
                           and then Node.Y + Node.Height <= Height,
                           "overlay accessibility stays inside the compact framebuffer");
                     end loop;
                     for Hit of Frame.Conflict_Hits loop
                        Assert
                          (Hit.Kind /= Conflict_Hit_None
                           and then Hit.Width > 0 and then Hit.Height > 0
                           and then Hit.X + Hit.Width <= Width
                           and then Hit.Y + Hit.Height <= Height,
                           "dialog hit regions stay inside the compact framebuffer");
                     end loop;
                     for Icon of Frame.Icons loop
                        if Icon.Overlay then
                           declare
                              Draw_W : constant Natural :=
                                (if Icon.Draw_Width > 0 then Icon.Draw_Width else Icon.Size);
                              Draw_H : constant Natural :=
                                (if Icon.Draw_Height > 0 then Icon.Draw_Height else Icon.Size);
                           begin
                              Assert
                                (Draw_W > 0 and then Draw_H > 0
                                 and then Icon.X + Draw_W <= Width
                                 and then Icon.Y + Draw_H <= Height,
                                 "overlay icons stay inside the compact framebuffer");
                           end;
                        end if;
                     end loop;
                  end;
               end loop;
            end loop;
         end;
      end loop;
   end Test_Compact_Overlay_Commands_Bounded;

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

      declare
         Overlay : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
      begin
         Overlay.Quick_Look_Open := True;
         Overlay.Context_Menu_Open := True;
         Overlay.Context_Menu_Target := Files.Model.Context_Menu_Item;
         Overlay.Context_Menu_X := Natural'Last;
         Overlay.Context_Menu_Y := Natural'Last;
         declare
            Overlay_Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout
                (Overlay, Natural'Last, Natural'Last, Positive'Last);
            Quick_Look : constant Quick_Look_Layout :=
              Calculate_Quick_Look_Layout (Overlay_Layout, Positive'Last);
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout
                (Overlay, Natural'Last, Natural'Last, Positive'Last);
         begin
            Assert
              (Quick_Look.Width <= Overlay_Layout.Width
               and then Quick_Look.Height <= Overlay_Layout.Height,
               "quick-look extreme dimensions remain inside the layout");
            Assert
              (Menu.X <= Natural'Last - Menu.Width
               and then Menu.Y <= Natural'Last - Menu.Height,
               "context-menu extreme coordinates remain representable");
         end;
      end;

      declare
         Boundary_Frame : Frame_Commands;
         Boundary_Menu  : Context_Menu_Layout;
      begin
         Boundary_Frame.Conflict_Hits.Append
           (Conflict_Hit_Region'
              (Kind   => Conflict_Hit_Replace,
             X      => Natural'Last,
             Y      => Natural'Last,
             Width  => 1,
             Height => 1));
         Assert
           (Conflict_Hit_At
              (Boundary_Frame, Natural'Last, Natural'Last).Kind =
                Conflict_Hit_Replace,
            "hit testing accepts a one-pixel region at the coordinate limit");

         Boundary_Menu.Visible := True;
         Boundary_Menu.X := Natural'Last;
         Boundary_Menu.Y := Natural'Last;
         Boundary_Menu.Width := 1;
         Boundary_Menu.Height := 1;
         Boundary_Menu.Row_Height := 1;
         Boundary_Menu.Row_Count := 1;
         Assert
           (Context_Menu_Row_At
              (Boundary_Menu, Natural'Last, Natural'Last) = 1,
            "context-menu hit testing accepts the coordinate limit");
      end;
   end Test_Extreme_Size_Saturation;

   procedure Test_Extension_Label_Extreme_Height
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Label : constant Files.Extension_Labels.Label :=
        Files.Extension_Labels.Label_For ("txt", Natural'Last, Theme_Dark);
   begin
      Assert
        (Label.Width = 0 and then Label.Height = 0 and then Label.Pixels.Is_Empty,
         "an impossible extension-label size fails closed");
   end Test_Extension_Label_Extreme_Height;

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

   procedure Test_Large_Icon_Badges_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Widths : constant array (Positive range <>) of Natural :=
        [20, 40, 80, 139, 140, 141, 280, 421, 640];
      Heights : constant array (Positive range <>) of Natural := [173, 300];
      Snap   : View_Snapshot := Sample_Snapshot (12, Files.Types.Large_Icons);
      Found  : Boolean := False;
   begin
      for Index in 1 .. Natural (Snap.Items.Length) loop
         declare
            Item : Item_Snapshot := Snap.Items.Element (Positive (Index));
         begin
            Item.Name := To_Unbounded_String ("item" & Integer'Image (Index) & ".txt");
            Snap.Items.Replace_Element (Positive (Index), Item);
         end;
      end loop;

      for Width of Widths loop
         for Height of Heights loop
            declare
               Layout : constant Guikit.Draw.Layout_Metrics :=
                 Calculate_Layout (Snap, Width, Height, 20);
               Frame  : constant Frame_Commands :=
                 Build_Frame_Commands (Snap, Width, Height, 20);
               Main_Right : constant Natural := Layout.Main_X + Layout.Main_Width;
               Main_Bottom : constant Natural := Layout.Main_Y + Layout.Main_Height;
            begin
               for Rect of Frame.Overlay_Rectangles loop
                  Assert
                    (Rect.X >= Layout.Main_X and then Rect.Y >= Layout.Main_Y
                     and then Rect.X + Rect.Width <= Main_Right
                     and then Rect.Y + Rect.Height <= Main_Bottom,
                     "extension-badge backgrounds stay inside the main viewport");
               end loop;
               for Icon of Frame.Icons loop
                  if Ada.Strings.Fixed.Index (To_String (Icon.Icon_Id), "extlabel:") = 1 then
                     Found := True;
                     Assert
                       (Icon.X >= Layout.Main_X and then Icon.Y >= Layout.Main_Y
                        and then Icon.X + Icon.Draw_Width <= Main_Right
                        and then Icon.Y + Icon.Draw_Height <= Main_Bottom,
                        "extension-label bitmaps stay inside the main viewport");
                  end if;
               end loop;
            end;
         end loop;
      end loop;
      Assert (Found, "the large-icon cases render at least one extension badge");
   end Test_Large_Icon_Badges_Bounded;

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
      declare
         Edge_Snapshot : View_Snapshot := Snapshot;
      begin
         Edge_Snapshot.Sort_Menu_Open := True;
         declare
            Edge_Frame : constant Frame_Commands :=
              Build_Frame_Commands (Edge_Snapshot, 1000, 800, 20);
            Right_Edge : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Edge_Snapshot, Edge_Frame,
                 X => 1000, Y => 400, Width => 1000, Height => 800);
            Bottom_Edge : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Edge_Snapshot, Edge_Frame,
                 X => 500, Y => 800, Width => 1000, Height => 800);
         begin
            Assert
              (Right_Edge.Kind = Files.Events.No_Input_Action,
               "the right framebuffer extent is not an actionable pixel");
            Assert
              (Bottom_Edge.Kind = Files.Events.No_Input_Action,
               "the bottom framebuffer extent is not an actionable pixel");
         end;
      end;
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

   --  An emoji in a filename draws as a picture, in both layers.
   --
   --  It cannot be a glyph quad: those read the alpha atlas, where a pixel is one
   --  coverage value with nowhere to keep a colour. So it leaves the text layer
   --  as an icon and joins the icon pass. This checks that seam end to end --
   --  decoder installed, font in the chain, picture produced -- because each part
   --  of it lives in a different crate and nothing else in CI renders an emoji.
   --
   --  The overlay layer is the half that had never been exercised: an emoji in a
   --  Quick Look title has to composite above the panel rather than under it.
   --
   --  Skipped where no colour font is installed, which is not a defect in files.
   procedure Test_Emoji_Draws_As_Colour_Icons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      Emoji_Font : constant String :=
        "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf";

      --  U+1F389 PARTY POPPER, spelled out so the file stays plain ASCII.
      Party : constant String :=
        Character'Val (16#F0#) & Character'Val (16#9F#)
        & Character'Val (16#8E#) & Character'Val (16#89#);

      Renderer : Text_Renderer;
      Frame    : Frame_Commands;
      Text     : Guikit.Draw.Text_Render_Result;

      function Line (Content : String) return Guikit.Draw.Text_Command is
         Cmd : Guikit.Draw.Text_Command;
      begin
         Cmd.X := 0;
         Cmd.Y := 0;
         Cmd.Width := 400;
         Cmd.Height := 20;
         Cmd.Text := To_Unbounded_String (Content);
         return Cmd;
      end Line;

      Main_Layer    : Natural := 0;
      Overlay_Layer : Natural := 0;
      Carried_Pictures : Natural := 0;
      Tile_Identity : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Emoji_Font) then
         return;
      end if;

      Assert
        (Initialize_Text (Renderer, Files.Fonts.Default_Font_Path, 16, 10, 20)
         = Guikit.Draw.Text_Render_Success,
         "the text renderer initialises");

      Frame.Text.Append (Line ("a " & Party & " b"));
      Frame.Overlay_Text.Append (Line ("c " & Party & " d"));

      Text := Build_Text_Glyphs (Renderer, Frame);

      Assert (Text.Status = Guikit.Draw.Text_Render_Success, "the text builds");
      Assert (Natural (Text.Colour_Icons.Length) = 2,
              "both emoji become colour icons, got"
              & Natural'Image (Natural (Text.Colour_Icons.Length)));

      for Icon of Text.Colour_Icons loop
         Assert (Icon.Thumbnail_Width > 0 and then Icon.Thumbnail_Height > 0,
                 "the picture has a size");
         Assert (Icon.Shared_Tile_Id /= Null_Unbounded_String,
                 "and names an identity so repeats share one atlas tile");
         if not Icon.Thumbnail_Pixels.Is_Empty then
            Assert
              (Natural (Icon.Thumbnail_Pixels.Length) = Icon.Thumbnail_Width * Icon.Thumbnail_Height * 4,
               "the carried picture has four bytes per pixel");
            Carried_Pictures := Carried_Pictures + 1;
            Tile_Identity := Icon.Shared_Tile_Id;
         else
            Assert (Icon.Shared_Tile_Id = Tile_Identity, "a repeated emoji reuses the carried picture's tile");
         end if;

         if Icon.Overlay then
            Overlay_Layer := Overlay_Layer + 1;
         else
            Main_Layer := Main_Layer + 1;
         end if;
      end loop;
      Assert (Carried_Pictures = 1, "the shared emoji picture is carried once across both layers");

      --  One from each layer: an emoji in an overlay must stay in the overlay,
      --  or it draws underneath the panel it belongs to.
      Assert (Main_Layer = 1 and then Overlay_Layer = 1,
              "one icon per layer, got" & Natural'Image (Main_Layer)
              & " main and" & Natural'Image (Overlay_Layer) & " overlay");

      --  Missing glyphs would mean it fell through to the '?' path instead.
      Assert (Text.Missing_Glyph_Count = 0, "and nothing was reported missing");
   end Test_Emoji_Draws_As_Colour_Icons;

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

      declare
         Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Built    : constant View_Snapshot := Build_Snapshot (Model, Settings);
         pragma Unreferenced (Built);
         Path     : constant String := Files.Model.Current_Path (Model);
      begin
         Assert
           (Free_Space_Cache_Is_Current (Path),
            "building a snapshot installs a current capacity sample");
         Assert
           (not Free_Space_Cache_Is_Current (Path & "/different"),
            "a capacity sample cannot validate a different path's frame cache");
      end;
   end Test_Bottom_Bar_Free_Space;

   --  Ada.Calendar.Time_Of reads its fields as local time, so a file stamped
   --  09:30 here must show 09:30 -- not that moment's UTC clock.
   procedure Test_Modified_Time_Is_Local (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);
      Frame    : Frame_Commands;
   begin
      Snapshot.Items (1).Modified_Available := True;
      Snapshot.Items (1).Modified_Time :=
        Ada.Calendar.Time_Of (2025, 1, 15, Duration (9 * 3_600 + 30 * 60 + 12));
      Frame := Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      --  The column may clip the seconds; the hour is what a time zone moves.
      Assert (Frame_Has_Text (Frame, "Jan 15, 2025 9:30"), "an older file shows its local clock time");
   end Test_Modified_Time_Is_Local;

   procedure Test_A11ykit_Tree_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Small_Icons);
      Frame    : Frame_Commands;
      Tree     : A11ykit.Tree.Accessibility_Tree;
      Profile  : constant Files.Rendering.Accessibility_Integration_Profile :=
        Files.Accessibility.Integration_Profile;
      Roots    : Natural := 0;
      Focused  : Natural := 0;
   begin
      for Index in 1 .. 2 loop
         declare
            Item : Item_Snapshot := Snapshot.Items.Element (Index);
         begin
            Item.Selected := True;
            Snapshot.Items.Replace_Element (Index, Item);
         end;
      end loop;
      Snapshot.Selected_Count := 2;
      Snapshot.Primary_Selected_Visible_Index := 2;
      Frame := Build_Frame_Commands
        (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
      Tree := Files.Accessibility.To_A11ykit_Tree (Frame);

      Assert
        (not Tree.Nodes.Is_Empty,
         "the frame's accessibility nodes map to a non-empty a11ykit tree");
      for Index in Tree.Nodes.First_Index .. Tree.Nodes.Last_Index loop
         --  A well-formed tree: every parent index is 0 (a root) or points at a
         --  real node in the tree.
         Assert
           (Tree.Nodes (Index).Parent <= Natural (Tree.Nodes.Length),
            "every node's parent index is within the tree");
         if Tree.Nodes (Index).Parent = 0 then
            Roots := Roots + 1;
         end if;
         if Tree.Nodes (Index).Node_State.Focused then
            Focused := Focused + 1;
         end if;
      end loop;
      Assert (Roots >= 1, "the mapped tree has at least one root node");
      Assert
        (Focused = 1,
         "multi-selection exports exactly one primary keyboard-focus node");
      Assert
        (A11ykit.Compatibility.Validate_Tree (Tree).Status =
           A11y.Results.Success,
         "the mapped tree satisfies the provider contract");

      Assert
        (Profile.Native_API_Binding_Status =
           (if A11y.Platforms.Current = A11y.Platforms.Unsupported
            then Files.File_System.Native_API_Binding_Missing
            else Files.File_System.Native_API_Binding_Available),
         "the integration profile reports whether this target has a native provider binding");

      --  The provider needs the first tree before it can register its native
      --  application root. Publication must therefore run even while Available
      --  is initially False; hosts without a live service use the validating
      --  fallback and still report a successful semantic publication.
      Files.Accessibility.Start;
      Files.Accessibility.Start;
      Files.Accessibility.Publish (Files.Accessibility.New_Window_Key, Frame);
      Assert
        (A11ykit.Provider.Last_Publish_Status = A11y.Results.Success,
         "the frame reaches the native provider or its validating fallback: "
         & A11y.Results.Status_Code'Image
             (A11ykit.Provider.Last_Publish_Status));
      Assert
        (A11ykit.Provider.Last_Published_Event_Count > 0,
         "accessibility publication delivers semantic events");
      Assert
        (A11ykit.Provider.Last_Publish_Backend_Name'Length > 0,
         "accessibility publication records the backend that consumed the frame");
      Files.Accessibility.Stop;
      Files.Accessibility.Stop;
      Assert
        (not Files.Accessibility.To_A11ykit_Tree (Frame).Nodes.Is_Empty,
         "the frame still maps after the provider lifetime has been started and stopped");
   end Test_A11ykit_Tree_Mapping;

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

      --  Three selected items with known sizes summing to 3 MB. The bottom bar
      --  reads the combined selection total (files plus measured folder sizes),
      --  which Build_Snapshot computes; here the snapshot is built directly, so
      --  set it to the sum.
      Mark_Selected (1, One_Mib);
      Mark_Selected (2, One_Mib);
      Mark_Selected (3, One_Mib);
      Snapshot.Selected_Count := 3;
      Snapshot.Selection_Total_Bytes := 3 * One_Mib;
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

   --  A root selector opens directly beneath the toolbar.  Hovering the
   --  toolbar button that opened it must not draw that button's tooltip over
   --  the selector; only regions belonging to the active selector survive.
   procedure Test_Overlay_Suppresses_Background_Tooltips
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout  : Guikit.Draw.Layout_Metrics;
      Root    : Root_Selector_Layout;
      Toolbar : Guikit.Layout.Toolbar_Layout;
   begin
      Snap.Root_Selector_Open := True;
      Snap.Root_Selected_Index := 1;
      Snap.Root_Paths.Append (To_Unbounded_String ("/"));
      Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));
      Layout  := Calculate_Layout (Snap, 480, 360, 20);
      Root    := Calculate_Root_Selector_Layout (Snap, Layout, 20);
      Toolbar := Guikit.Layout.Calculate_Toolbar_Layout (480);

      declare
         Button_X : constant Natural := Guikit.Layout.Toolbar_Left_Button_X (Toolbar, 0);
         Button_W : constant Natural := Guikit.Layout.Toolbar_Left_Button_Width (Toolbar, 0);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands
             (Snap,
              480,
              360,
              20,
              Hover_X   => Button_X + Button_W / 2,
              Hover_Y   => Guikit.Layout.Toolbar_Input_Y (20) + 10,
              Has_Hover => True);
      begin
         for Tip of Frame.Tooltips loop
            Assert
              (Tip.Y >= Root.Y,
               "the active root selector retains no tooltip region from the toolbar behind it");
         end loop;
      end;
   end Test_Overlay_Suppresses_Background_Tooltips;

   --  The selector floats over file content.  Its two offset strips are a
   --  drop shadow, not an opaque second pane: using Pane_Color here produces
   --  a conspicuous solid ledge in the light theme.
   procedure Test_Root_Selector_Uses_Shadow_Color
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap         : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Shadow_Count : Natural := 0;
   begin
      Snap.Root_Selector_Open := True;
      Snap.Root_Selected_Index := 1;
      Snap.Root_Paths.Append (To_Unbounded_String ("/"));
      Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));

      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 480, 360, 20);
         Root   : constant Root_Selector_Layout := Calculate_Root_Selector_Layout (Snap, Layout, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 480, 360, 20);
         Dismiss : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snap, Frame, X => 479, Y => 359, Width => 480, Height => 360, Line_Height => 20);
         A11y_Count : Natural := 0;
      begin
         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Shadow_Color then
               Shadow_Count := Shadow_Count + 1;
            end if;
         end loop;
         Assert
           (Dismiss.Kind = Files.Events.Command_Input_Action
            and then Dismiss.Command = Files.Commands.Close_Command_Palette_Command,
            "a click outside the root selector dismisses it without activating the background");
         for Node of Frame.Accessibility loop
            A11y_Count := A11y_Count + 1;
            Assert
              (Node.X >= Root.X
               and then Node.Y >= Root.Y
               and then Node.X + Node.Width <= Root.X + Root.Width
               and then Node.Y + Node.Height <= Root.Y + Root.Height,
               "the root selector exposes no background accessibility nodes");
         end loop;
         Assert (A11y_Count > 1, "the root selector retains its list choices and close button");
      end;

      Assert
        (Shadow_Count = Shadow_Rectangles,
         "the root selector emits the shared banded translucent drop shadow");
   end Test_Root_Selector_Uses_Shadow_Color;

   --  Conflict resolution consumes every click while it is open.  Dim the
   --  inactive file view so the visual hierarchy communicates the same modal
   --  state as the event reducer, and place the dialog above that scrim.
   procedure Test_Paste_Conflict_Has_Modal_Backdrop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 640;
      Height : constant Natural  := 480;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout : Guikit.Draw.Layout_Metrics;
      Dialog : Conflict_Dialog_Layout;
      Backdrop_Seen     : Boolean := False;
      Panel_Seen        : Boolean := False;
      Shadow_Before_Panel : Natural := 0;
      Accessibility_Count : Natural := 0;
   begin
      Snap.Paste_Conflict_Open := True;
      Snap.Paste_Conflict_Name := To_Unbounded_String ("report.txt");
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Dialog := Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);

      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Modal_Backdrop_Color
              and then Rect.X = 0
              and then Rect.Y = 0
              and then Rect.Width = Width
              and then Rect.Height = Height
            then
               Backdrop_Seen := True;
            elsif Rect.Color = Shadow_Color and then not Panel_Seen then
               Shadow_Before_Panel := Shadow_Before_Panel + 1;
            elsif Rect.Color = Overlay_Color
              and then Rect.X = Dialog.X
              and then Rect.Y = Dialog.Y
              and then Rect.Width = Dialog.Width
              and then Rect.Height = Dialog.Height
            then
               Assert
                 (Backdrop_Seen,
                  "the modal backdrop is emitted before the conflict-dialog surface");
               Panel_Seen := True;
            end if;
         end loop;

         for Node of Frame.Accessibility loop
            Accessibility_Count := Accessibility_Count + 1;
            Assert
              (Node.X >= Dialog.X
               and then Node.Y >= Dialog.Y
               and then Node.X + Node.Width <= Dialog.X + Dialog.Width
               and then Node.Y + Node.Height <= Dialog.Y + Dialog.Height,
               "a modal conflict dialog exposes no background accessibility nodes");
         end loop;
      end;

      Assert (Backdrop_Seen, "the paste-conflict dialog emits a full-window modal backdrop");
      Assert (Panel_Seen, "the paste-conflict dialog emits its panel surface");
      Assert
        (Shadow_Before_Panel = Shadow_Rectangles,
         "the paste-conflict dialog emits the shared shadow before its panel surface");
      Assert
        (Accessibility_Count > 0,
         "the modal conflict dialog retains its own accessibility nodes");
   end Test_Paste_Conflict_Has_Modal_Backdrop;

   --  Hover the toolbar button whose tooltip text is longest, then count the
   --  overlay rows that render that tooltip: a narrow window wraps it onto
   --  several rows, a wide one keeps it on a single row.
   procedure Test_Input_Scroll_Keeps_Caret_Visible (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Line_Height : constant Positive := 20;
      Char_W      : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Text        : constant String (1 .. 100) := [others => 'a'];
      Width       : constant Natural := 20 * Char_W;
      Scroll      : constant Natural :=
        Files.Rendering.Input_Scroll_Columns (Text, Text'Length, Width, Line_Height);
   begin
      Assert (Files.Rendering.Input_Scroll_Columns (Text, 5, Width, Line_Height) = 0,
              "a caret within the field needs no scroll");
      Assert (Scroll > 0 and then Text'Length - Scroll < 20,
              "a caret at the end of overlong text is scrolled into the field");
      Assert (Files.Rendering.Input_Scroll_Columns ("short", 5, Width, Line_Height) = 0,
              "text that fits is never scrolled");
   end Test_Input_Scroll_Keeps_Caret_Visible;

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

         declare
            Clipped : Context_Menu_Layout := Menu;
            Probe_X : constant Natural := Menu.X + Menu.Width / 2;
            Probe_Y : constant Natural := Menu.Y + Menu.Padding;
         begin
            --  Model the renderer clipping the panel before its first row. The
            --  hit test must honor the declared surface, not the latent rows.
            Clipped.Height := Menu.Padding;
            Assert
              (Context_Menu_Row_At (Clipped, Probe_X, Probe_Y) = 0,
               "a row outside the declared context-menu height is not clickable");
         end;
      end;

      --  The complete item menu must remain on-screen and mouse-reachable at
      --  the compact live-smoke height.  It uses two columns, split at a group
      --  boundary, rather than clipping its lower commands.
      declare
         Menu : constant Context_Menu_Layout :=
           Calculate_Context_Menu_Layout (Snapshot, 480, 360, 20);
      begin
         Assert (Menu.Column_Count = 2, "the compact item menu uses two columns");
         Assert (Menu.Height <= 360, "the compact item menu stays within the window height");
         Assert
           (Menu.Column_Break_Row > 0 and then Menu.Column_Break_Row < Menu.Row_Count,
            "the compact item menu splits between two non-empty columns");

         for Row in 1 .. Menu.Row_Count loop
            if Menu.Row_Kinds (Row) = Command_Row then
               declare
                  Probe_X : constant Natural :=
                    Context_Menu_Row_Left (Menu, Row) + Context_Menu_Row_Width (Menu, Row) / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Row_Height / 2;
               begin
                  Assert
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y) = Row,
                     "every compact-menu command hit-tests in its displayed column");
               end;
            end if;
         end loop;
      end;
   end Test_Context_Menu_Separators;

   --  Menus float over the file view.  Use the same opaque overlay surface and
   --  translucent banded shadow as the root selector instead of rendering a
   --  flat pane that visually merges with the content beneath it.
   procedure Test_Floating_Menus_Have_Elevation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      declare
         Snap : View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      begin
         Snap.Context_Menu_Open := True;
         Snap.Context_Menu_Target := Files.Model.Context_Menu_Item;
         Snap.Context_Menu_X := 100;
         Snap.Context_Menu_Y := 100;

         declare
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout (Snap, Width, Height, LH);
            Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
            Shadow_Count : Natural := 0;
            Surface_Seen : Boolean := False;
            A11y_Count : Natural := 0;
         begin
            for Rect of Frame.Overlay_Rectangles loop
               if Rect.Color = Shadow_Color then
                  Shadow_Count := Shadow_Count + 1;
               elsif Rect.Color = Overlay_Color
                 and then Rect.X = Menu.X
                 and then Rect.Y = Menu.Y
                 and then Rect.Width = Menu.Width
                 and then Rect.Height = Menu.Height
               then
                  Surface_Seen := True;
               end if;
            end loop;
            Assert (Shadow_Count = Shadow_Rectangles, "the context menu uses the shared banded shadow");
            Assert (Surface_Seen, "the context menu uses the opaque overlay surface role");
            for Node of Frame.Accessibility loop
               A11y_Count := A11y_Count + 1;
               Assert
                 (Node.X >= Menu.X
                  and then Node.Y >= Menu.Y
                  and then Node.X + Node.Width <= Menu.X + Menu.Width
                  and then Node.Y + Node.Height <= Menu.Y + Menu.Height,
                  "the context menu exposes no background accessibility nodes");
            end loop;
            Assert (A11y_Count > 1, "the context menu retains its list and command choices");
         end;
      end;

      declare
         Snap : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      begin
         Snap.Sort_Menu_Open := True;
         declare
            Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
            Shadow_Count : Natural := 0;
            A11y_Count : Natural := 0;
            Dismiss : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snap, Frame, X => Width / 2, Y => 10,
                 Width => Width, Height => Height, Line_Height => LH);
         begin
            for Rect of Frame.Overlay_Rectangles loop
               if Rect.Color = Shadow_Color then
                  Shadow_Count := Shadow_Count + 1;
               end if;
            end loop;
            Assert (Shadow_Count = Shadow_Rectangles, "the sort menu uses the shared banded shadow");
            Assert
              (Dismiss.Kind = Files.Events.Command_Input_Action
               and then Dismiss.Command = Files.Commands.Close_Command_Palette_Command,
               "a click outside the sort menu dismisses it without activating the background");
            for Node of Frame.Accessibility loop
               A11y_Count := A11y_Count + 1;
               Assert
                 (Node.Role = Role_List or else Node.Role = Role_List_Item,
                  "the open sort menu exposes no background accessibility nodes");
            end loop;
            Assert (A11y_Count = 6, "the sort menu exposes its list and five sort choices");
         end;
      end;
   end Test_Floating_Menus_Have_Elevation;

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
         declare
            Compact_Layout : constant Guikit.Draw.Layout_Metrics :=
              Calculate_Layout (Snap, 12, 200, LH);
            Compact_Root : constant Root_Selector_Layout :=
              Calculate_Root_Selector_Layout (Snap, Compact_Layout, LH);
            Compact_Rows : constant Root_Path_Layout_Vectors.Vector :=
              Calculate_Root_Path_Layout (Snap, Compact_Root);
         begin
            Assert (not Compact_Rows.Is_Empty, "the compact root selector retains a visible row");
            for Row of Compact_Rows loop
               Assert
                 (Row.X >= Compact_Root.X
                  and then Row.X + Row.Width <= Compact_Root.X + Compact_Root.Width,
                  "compact root rows stay within the selector width");
            end loop;
         end;
      end;

      --  Folder-tree sidebar.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Panel  : Tree_Panel_Layout;
         Rows   : Tree_Row_Layout_Vectors.Vector;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Tree_Panel_Open := True;
         Snap.Tree_Rows.Append
           (Files.Folder_Tree.Visible_Row'
              (Node_Index   => 1,
               Path         => To_Unbounded_String ("/deep"),
               Name         => To_Unbounded_String ("deep"),
               Depth        => 20,
               Expanded     => False,
               Loaded       => True,
               Has_Children => True));
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Panel  := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Rows   := Calculate_Tree_Row_Layout (Snap, Panel, LH);
         Close  := Panel_Close_Button (Panel.X, Panel.Y, Panel.Width, Panel.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the folder tree hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open folder tree emits a close-button accessibility node");
         Assert
           (not Rows.Is_Empty
            and then Rows.First_Element.Triangle_W = 0,
            "a deeply indented expander clipped outside the sidebar is not clickable");

         --  The tree can remain visible beneath the modal settings pane. Its
         --  close button must not receive a click through that overlay.
         Snap.Settings_Pane_Open := True;
         Frame := Build_Frame_Commands (Snap, Width, Height, LH);
         declare
            Covered_Close : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snap, Frame,
                 Close.X + Close.Width / 2,
                 Close.Y + Close.Height / 2,
                 Width, Height, Line_Height => LH);
         begin
            Assert
              (Covered_Close.Kind /= Files.Events.Command_Input_Action
               or else Covered_Close.Command /= Files.Commands.Toggle_Folder_Tree_Command,
               "the modal settings pane owns clicks above the visible folder tree");
         end;

         --  Quick Look is a higher modal layer than the persistent tree. It
         --  clears the tree from the active accessibility surface after the
         --  tree has been drawn underneath it.
         Snap.Settings_Pane_Open := False;
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Name := To_Unbounded_String ("preview.txt");
         Frame := Build_Frame_Commands (Snap, Width, Height, LH);
         declare
            Tree_Accessible : Boolean := False;
         begin
            for Node of Frame.Accessibility loop
               Tree_Accessible :=
                 Tree_Accessible
                 or else To_String (Node.Name) =
                   Files.Localization.Text ("accessibility.tree_panel");
            end loop;
            Assert
              (not Tree_Accessible,
               "Quick Look hides the covered folder tree from accessibility");
         end;
      end;

      --  A scrolled destination tree maps its clipped layout rows back to the
      --  correct source rows and leaves the picker footer unobstructed.
      declare
         Snap       : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout     : Guikit.Draw.Layout_Metrics;
         Panel      : Tree_Panel_Layout;
         Buttons    : Tree_Pick_Button_Layout;
         Rows       : Tree_Row_Layout_Vectors.Vector;
         Frame      : Frame_Commands;
         Fourth_Seen : Boolean := False;
      begin
         Snap.Tree_Panel_Open := True;
         Snap.Tree_Pick_Active := True;
         Snap.Tree_Panel_Scroll_Rows := 3;
         for Index in 1 .. 12 loop
            Snap.Tree_Rows.Append
              (Files.Folder_Tree.Visible_Row'
                 (Node_Index   => Index,
                  Path         => To_Unbounded_String
                    ("/tree/" & Natural'Image (Index)),
                  Name         => To_Unbounded_String
                    ("tree-row" & Natural'Image (Index)),
                  Depth        => 0,
                  Expanded     => False,
                  Loaded       => True,
                  Has_Children => False));
         end loop;

         Layout  := Calculate_Layout (Snap, Width, 200, LH);
         Panel   := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Buttons := Tree_Pick_Buttons (Panel, LH);
         Rows    := Calculate_Tree_Row_Layout (Snap, Panel, LH);
         Frame   := Build_Frame_Commands (Snap, Width, 200, LH);

         Assert
           (not Rows.Is_Empty
            and then Rows.First_Element.Visible_Row_Index = 4
            and then Rows.First_Element.Node_Index = 4,
            "tree scrolling lays out the requested source row first");
         Assert
           (Panel.Scrollbar_Visible
            and then Panel.Scrollbar_Height > 0
            and then Panel.Scrollbar_Track_Height > Panel.Scrollbar_Height,
            "an overflowing tree exposes a bounded scrollbar thumb");
         Assert
           (not Buttons.Visible
            or else Panel.Scrollbar_Y + Panel.Scrollbar_Track_Height <= Buttons.Y,
            "the tree scrollbar track stays above the destination-picker footer");
         for Row of Rows loop
            Assert
              (not Buttons.Visible
               or else Row.Y + Row.Height <= Buttons.Y,
               "scrolled destination rows stay above the picker button bar");
         end loop;
         for Node of Frame.Accessibility loop
            if To_String (Node.Name) = "tree-row 4" then
               Fourth_Seen := True;
            end if;
         end loop;
         Assert
           (Fourth_Seen,
            "rendering and accessibility use the scrolled row's source data");
      end;

      --  Folder-tree destination picker: the Choose/Cancel button bar. Covers the
      --  Tree_Pick_Active render + hit-test path, which no other test exercises.
      declare
         Snap       : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout     : Guikit.Draw.Layout_Metrics;
         Panel      : Tree_Panel_Layout;
         Buttons    : Tree_Pick_Button_Layout;
         Frame      : Frame_Commands;
         Choose_Hit : Files.Events.Input_Action;
         Cancel_Hit : Files.Events.Input_Action;
         Outside_Hit : Files.Events.Input_Action;
         Backdrop_Seen : Boolean := False;
         A11y_Count : Natural := 0;
      begin
         Snap.Tree_Panel_Open  := True;
         Snap.Tree_Pick_Active := True;
         Layout  := Calculate_Layout (Snap, Width, Height, LH);
         Panel   := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
         Buttons := Tree_Pick_Buttons (Panel, LH);
         Frame   := Build_Frame_Commands (Snap, Width, Height, LH);

         Assert (Buttons.Visible, "the active tree destination picker shows a Choose/Cancel bar");
         Assert
           (Buttons.Button_Width > 0 and then Buttons.Height > 0,
            "the pick buttons have a non-empty click area");
         Assert (Buttons.Choose_X < Buttons.Cancel_X, "Choose sits left of Cancel");
         Assert
           (Buttons.Choose_X + Buttons.Button_Width <= Buttons.Cancel_X,
            "the Choose and Cancel buttons do not overlap");
         Assert
           (Buttons.Choose_X >= Panel.X
              and then Buttons.Cancel_X + Buttons.Button_Width <= Panel.X + Panel.Width,
            "both pick buttons sit within the tree panel");

         --  Each button center is hit-testable and routes to the right action.
         Choose_Hit :=
           Files.Events.Translate_Click
             (Snap, Frame,
              X      => Buttons.Choose_X + Buttons.Button_Width / 2,
              Y      => Buttons.Y + Buttons.Height / 2,
              Width  => Width,
              Height => Height);
         Cancel_Hit :=
           Files.Events.Translate_Click
             (Snap, Frame,
              X      => Buttons.Cancel_X + Buttons.Button_Width / 2,
              Y      => Buttons.Y + Buttons.Height / 2,
              Width  => Width,
              Height => Height);
         Outside_Hit :=
           Files.Events.Translate_Click
             (Snap, Frame,
              X      => Panel.X + Panel.Width + 20,
              Y      => Panel.Y + 20,
              Width  => Width,
              Height => Height);
         Assert
           (Choose_Hit.Kind = Files.Events.Tree_Pick_Confirm_Input_Action,
            "clicking Choose confirms the destination pick");
         Assert
           (Cancel_Hit.Kind = Files.Events.Command_Input_Action
              and then Cancel_Hit.Command = Files.Commands.Toggle_Folder_Tree_Command,
            "clicking Cancel closes the picker");
         Assert
           (Outside_Hit.Kind = Files.Events.No_Input_Action,
            "a destination-picker click outside the tree cannot activate the background");

         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Modal_Backdrop_Color
              and then Rect.X = 0
              and then Rect.Y = 0
              and then Rect.Width = Width
              and then Rect.Height = Height
            then
               Backdrop_Seen := True;
            end if;
         end loop;
         Assert (Backdrop_Seen, "the modal destination picker dims the inactive file view");

         for Node of Frame.Accessibility loop
            A11y_Count := A11y_Count + 1;
            Assert
              (Node.X >= Panel.X
               and then Node.Y >= Panel.Y
               and then Node.X + Node.Width <= Panel.X + Panel.Width
               and then Node.Y + Node.Height <= Panel.Y + Panel.Height,
               "the modal destination picker exposes no background accessibility nodes");
         end loop;
         Assert
           (A11y_Count >= 3,
            "the destination picker retains its tree and Choose/Cancel accessibility nodes");
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
         Backdrop_Seen : Boolean := False;
         Shadow_Count  : Natural := 0;
         Accessibility_Count : Natural := 0;
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
         Assert
           (Frame_Has_Text (Frame, "3 of 10"),
            "the progress overlay keeps the completed and total item counts when no label is present");
         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Modal_Backdrop_Color
              and then Rect.X = 0
              and then Rect.Y = 0
              and then Rect.Width = Width
              and then Rect.Height = Height
            then
               Backdrop_Seen := True;
            elsif Rect.Color = Shadow_Color then
               Shadow_Count := Shadow_Count + 1;
            end if;
         end loop;
         Assert (Backdrop_Seen, "blocking paste progress dims the inactive file view");
         Assert (Shadow_Count = Shadow_Rectangles, "paste progress uses the shared banded panel shadow");

         for Node of Frame.Accessibility loop
            Accessibility_Count := Accessibility_Count + 1;
            Assert
              (Node.X >= Panel.X
               and then Node.Y >= Panel.Y
               and then Node.X + Node.Width <= Panel.X + Panel.Width
               and then Node.Y + Node.Height <= Panel.Y + Panel.Height,
               "blocking paste progress exposes no background accessibility nodes");
         end loop;
         Assert
           (Accessibility_Count > 0,
            "blocking paste progress retains its dialog and Cancel accessibility nodes");
      end;

      --  Blocking dialogs must remain fully operable in a short/narrow window:
      --  previously their fixed desktop height left live controls below the
      --  framebuffer even though the panel started at its top edge.
      declare
         Compact_W : constant Natural := 80;
         Compact_H : constant Natural := 100;
         Snap      : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
         Layout    : Guikit.Draw.Layout_Metrics;
      begin
         Snap.Paste_Conflict_Open := True;
         Snap.Paste_Conflict_Name := To_Unbounded_String ("conflict.txt");
         Layout := Calculate_Layout (Snap, Compact_W, Compact_H, LH);
         declare
            Dialog : constant Conflict_Dialog_Layout :=
              Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
         begin
            Assert
              (Dialog.X + Dialog.Width <= Compact_W
               and then Dialog.Y + Dialog.Height <= Compact_H,
               "the compact conflict dialog stays inside the framebuffer");
            Assert
              (Dialog.Cancel_X + Dialog.Button_Width <= Dialog.X + Dialog.Width
               and then Dialog.Button_Y + Dialog.Button_Height <= Dialog.Y + Dialog.Height,
               "the compact conflict action row stays inside its panel");
            for Node of Frame.Accessibility loop
               Assert
                 (Node.X >= Dialog.X
                  and then Node.Y >= Dialog.Y
                  and then Node.X + Node.Width <= Dialog.X + Dialog.Width
                  and then Node.Y + Node.Height <= Dialog.Y + Dialog.Height,
                  "compact conflict accessibility controls stay inside the panel");
            end loop;
         end;

         Snap.Paste_Conflict_Open := False;
         Snap.Paste_Progress_Open := True;
         Snap.Paste_Progress_Total := 2;
         Snap.Paste_Progress_Done := 1;
         Layout := Calculate_Layout (Snap, Compact_W, Compact_H, LH);
         declare
            Panel : constant Paste_Progress_Layout :=
              Calculate_Paste_Progress_Layout (Snap, Layout, LH);
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
         begin
            Assert
              (Panel.X + Panel.Width <= Compact_W
               and then Panel.Y + Panel.Height <= Compact_H,
               "the compact paste-progress panel stays inside the framebuffer");
            Assert
              (Panel.Cancel_X + Panel.Cancel_Width <= Panel.X + Panel.Width
               and then Panel.Cancel_Y + Panel.Cancel_Height <= Panel.Y + Panel.Height,
               "the compact progress Cancel button stays inside its panel");
            for Node of Frame.Accessibility loop
               Assert
                 (Node.X >= Panel.X
                  and then Node.Y >= Panel.Y
                  and then Node.X + Node.Width <= Panel.X + Panel.Width
                  and then Node.Y + Node.Height <= Panel.Y + Panel.Height,
                  "compact progress accessibility controls stay inside the panel");
            end loop;
         end;
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

      --  When the compact panel cannot display every loaded line, its final
      --  row explicitly says the preview is truncated instead of silently
      --  ending at an arbitrary source line.
      declare
         Snap  : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Frame : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Text_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("long.txt");
         for Line in 1 .. 30 loop
            Snap.Quick_Look_Text_Lines.Append
              (To_Unbounded_String ("preview line" & Integer'Image (Line)));
         end loop;
         Frame := Build_Frame_Commands (Snap, 480, 360, LH);
         Assert
           (Frame_Has_Text (Frame, Files.Localization.Text ("quick_look.truncated")),
            "a compact quick look marks panel-height truncation");
         Assert
           (not Frame_Has_Text (Frame, "preview line 30"),
            "a compact quick look reserves its final visible row for the truncation notice");
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

      Icon_Overlay      : Boolean := False;
      A11y_Count       : Natural := 0;
      Dialog_Described : Boolean := False;
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

      for Node of Frame.Accessibility loop
         A11y_Count := A11y_Count + 1;
         Assert
           (Node.X >= QL.X
            and then Node.Y >= QL.Y
            and then Node.X + Node.Width <= QL.X + QL.Width
            and then Node.Y + Node.Height <= QL.Y + QL.Height,
            "Quick Look exposes no background accessibility nodes");
         if Node.Role = Role_Dialog
           and then Node.Description = Snap.Quick_Look_Name
         then
            Dialog_Described := True;
         end if;
      end loop;
      Assert (A11y_Count > 0, "Quick Look retains its own accessibility nodes");
      Assert
        (Dialog_Described,
         "the Quick Look dialog identifies the item currently being previewed");

      --  The generic info preview used to size its icon from width alone, so a
      --  short panel drew the icon and following metadata through its bottom
      --  border.  Every emitted preview command must fit the compact panel.
      declare
         Compact_W      : constant Natural := 160;
         Compact_H      : constant Natural := 80;
         Compact_Layout : constant Guikit.Draw.Layout_Metrics :=
           Calculate_Layout (Snap, Compact_W, Compact_H, LH);
         Compact_QL     : constant Quick_Look_Layout :=
           Calculate_Quick_Look_Layout (Compact_Layout, LH);
         Compact_Frame  : constant Frame_Commands :=
           Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
      begin
         Assert
           (Compact_QL.Content_X + Compact_QL.Content_Width
              <= Compact_QL.X + Compact_QL.Width
            and then Compact_QL.Content_Y + Compact_QL.Content_Height
              <= Compact_QL.Y + Compact_QL.Height,
            "the compact Quick Look content box stays inside its panel");
         for Icon of Compact_Frame.Icons loop
            if Icon.Overlay then
               Assert
                 (Icon.X + Icon.Size <= Compact_QL.X + Compact_QL.Width
                  and then Icon.Y + Icon.Size <= Compact_QL.Y + Compact_QL.Height,
                  "a compact Quick Look info icon stays inside the panel");
            end if;
         end loop;
         for Text of Compact_Frame.Overlay_Text loop
            Assert
              (Text.X + Text.Width <= Compact_QL.X + Compact_QL.Width
               and then Text.Y + Text.Height <= Compact_QL.Y + Compact_QL.Height,
               "compact Quick Look text stays inside the panel");
         end loop;
      end;
   end Test_Quick_Look_Drawn_In_Overlay;

   --  File icons are submitted after main-layer rectangles and text.  A
   --  floating picker therefore has to live wholly in the overlay layer or a
   --  grid icon beneath it can punch through the panel.
   procedure Test_Label_Picker_Drawn_In_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      Picker : Label_Picker_Layout;
      Frame  : Frame_Commands;
      A11y_Count : Natural := 0;

      function Panel_Bg_In (Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector) return Boolean is
      begin
         for Rect of Rects loop
            if Rect.Color = Pane_Color
              and then Rect.X = Picker.X
              and then Rect.Y = Picker.Y
              and then Rect.Width = Picker.Width
              and then Rect.Height = Picker.Height
            then
               return True;
            end if;
         end loop;
         return False;
      end Panel_Bg_In;
   begin
      Snap.Label_Picker_Open := True;
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Picker := Calculate_Label_Picker_Layout (Layout, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);

      Assert
        (Panel_Bg_In (Frame.Overlay_Rectangles),
         "the label picker panel background is drawn in the overlay layer");
      Assert
        (not Panel_Bg_In (Frame.Rectangles),
         "the label picker panel background does not remain beneath grid icons");
      for Node of Frame.Accessibility loop
         A11y_Count := A11y_Count + 1;
         Assert
           (Node.X >= Picker.X
            and then Node.Y >= Picker.Y
            and then Node.X + Node.Width <= Picker.X + Picker.Width
            and then Node.Y + Node.Height <= Picker.Y + Picker.Height,
            "the label picker exposes no background accessibility nodes");
      end loop;
      Assert
        (A11y_Count > 1,
         "the label picker retains its dialog and color-choice accessibility nodes");

      --  A compact window clips the panel itself.  Its swatches and assistive
      --  hit regions must shrink with it instead of retaining desktop-sized
      --  geometry outside the visible panel.
      declare
         Compact_W      : constant Natural := 160;
         Compact_H      : constant Natural := 55;
         Compact_Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Compact_Layout : Guikit.Draw.Layout_Metrics;
         Compact_Picker : Label_Picker_Layout;
         Compact_Frame  : Frame_Commands;
      begin
         Compact_Snap.Label_Picker_Open := True;
         Compact_Layout := Calculate_Layout (Compact_Snap, Compact_W, Compact_H, LH);
         Compact_Picker := Calculate_Label_Picker_Layout (Compact_Layout, LH);
         Compact_Frame := Build_Frame_Commands (Compact_Snap, Compact_W, Compact_H, LH);

         Assert
           (Compact_Picker.Swatch_Size > 0,
            "a compact but usable picker retains visible color swatches");
         for Swatch of Compact_Picker.Swatches loop
            Assert
              (Swatch.X >= Compact_Picker.X
               and then Swatch.Y >= Compact_Picker.Y
               and then Swatch.X + Swatch.Width <= Compact_Picker.X + Compact_Picker.Width
               and then Swatch.Y + Swatch.Height <= Compact_Picker.Y + Compact_Picker.Height,
               "every compact color swatch stays inside the picker panel");
         end loop;
         for Node of Compact_Frame.Accessibility loop
            Assert
              (Node.X >= Compact_Picker.X
               and then Node.Y >= Compact_Picker.Y
               and then Node.X + Node.Width <= Compact_Picker.X + Compact_Picker.Width
               and then Node.Y + Node.Height <= Compact_Picker.Y + Compact_Picker.Height,
               "compact picker accessibility regions stay inside the visible panel");
         end loop;
      end;
   end Test_Label_Picker_Drawn_In_Overlay;

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
   --  representative role, and high contrast must use its own stronger dark
   --  palette rather than silently aliasing the ordinary dark theme.
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Palette_Color;
      Dark_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Dark);
      Light_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_Light);
      Dark_Text   : constant Palette_Color := Color_For (Text_Color, Theme_Dark);
      Light_Text  : constant Palette_Color := Color_For (Text_Color, Theme_Light);
      Contrast_Canvas : constant Palette_Color := Color_For (Canvas_Color, Theme_High_Contrast);
      Contrast_Text   : constant Palette_Color := Color_For (Text_Color, Theme_High_Contrast);
      Contrast_Border : constant Palette_Color := Color_For (Border_Color, Theme_High_Contrast);
      Dark_Border     : constant Palette_Color := Color_For (Border_Color, Theme_Dark);
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
      Assert (Contrast_Canvas /= Dark_Canvas,
              "high contrast has a distinct canvas palette");
      Assert (Contrast_Text.R > Dark_Text.R,
              "high contrast text is brighter than dark-theme text");
      Assert (Contrast_Border.R > Dark_Border.R,
              "high contrast borders are stronger than dark-theme borders");
      Assert
        (Color_For (Canvas_Color) = Dark_Canvas,
         "the palette defaults to the dark theme");
   end Test_Theme_Palette_Selection;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Rendering_Test_Case));
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
      function Find_Clipped_Width return Natural is
      begin
         for Width in 1 .. 1_000 loop
            declare
               Bar : constant Guikit.Layout.Bottom_Bar_Layout :=
                 Files.UI.Calculate_Bottom_Bar_Layout
                   (Width, Files.Model.Sort_Name, 20);
            begin
               if Bar.Sort_Button_Width > 0
                 and then Bar.Sort_Button_X + Files.UI.Sort_Menu_Width (20) > Width
               then
                  return Width;
               end if;
            end;
         end loop;
         return 0;
      end Find_Clipped_Width;

      Name_Bar : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Name, 20);
      Chg_Bar  : constant Guikit.Layout.Bottom_Bar_Layout :=
        Files.UI.Calculate_Bottom_Bar_Layout (1000, Files.Model.Sort_Changed, 20);
      Menu_W   : constant Natural := Files.UI.Sort_Menu_Width (20);
      Compact_W : constant Natural := Find_Clipped_Width;
   begin
      Assert (Name_Bar.Sort_Button_Width > 0 and then Chg_Bar.Sort_Button_Width > 0,
              "the sort button is laid out for both fields");
      Assert (Name_Bar.Sort_Button_Width < Chg_Bar.Sort_Button_Width,
              "the sort button is narrower for a shorter field label");
      Assert (Menu_W >= Chg_Bar.Sort_Button_Width,
              "the sort menu is at least as wide as the widest field's button");
      Assert (Menu_W > Name_Bar.Sort_Button_Width,
              "the sort menu is wider than the snug button for a short field");
      Assert (Compact_W > 0, "a compact width clips the preferred sort menu");
      if Compact_W > 0 then
         declare
            Height   : constant Natural := 800;
            Row_H    : constant Natural :=
              20 + 2 * Guikit.Layout.Bottom_Bar_Padding;
            Bottom_Y : constant Natural := Height - Row_H;
            Menu_H   : constant Natural :=
              5 * Row_H + 2 * Guikit.Layout.Sort_Menu_Padding;
            Rows_Y   : constant Natural :=
              Bottom_Y - Menu_H + Guikit.Layout.Sort_Menu_Padding;
            Row_Y    : constant Natural := Rows_Y + Row_H / 2;
            Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
              Files.UI.Calculate_Bottom_Bar_Layout
                (Compact_W, Files.Model.Sort_Name, 20);
            Visible_W : constant Natural :=
              Files.UI.Sort_Menu_Visible_Width
                (Compact_W, Files.Model.Sort_Name, 20);
         begin
            Assert
              (Bar.Sort_Button_X + Visible_W = Compact_W,
               "the visible sort menu stops at the right framebuffer edge");
            Assert
              (Visible_W < Menu_W,
               "the compact sort menu is clipped from its preferred width");
            Assert
              (Files.UI.Bottom_Bar_Sort_Menu_Command_At
                 (Compact_W, Row_Y, Compact_W, Height,
                  Files.Model.Sort_Name, 20) = Files.Commands.No_Command,
               "the clipped sort-menu edge cannot select a row");
            Assert
              (not Files.UI.Bottom_Bar_Sort_Menu_Contains
                 (Compact_W, Row_Y, Compact_W, Height,
                  Files.Model.Sort_Name, 20),
               "the clipped sort-menu edge is outside the menu");
         end;
      end if;

      declare
         Short_H : constant Natural := 20;
         Bar     : constant Guikit.Layout.Bottom_Bar_Layout :=
           Files.UI.Calculate_Bottom_Bar_Layout
             (1000, Files.Model.Sort_Name, 20);
      begin
         Assert
           (Files.UI.Bottom_Bar_Sort_Menu_Command_At
              (Bar.Sort_Button_X, 0, 1000, Short_H,
               Files.Model.Sort_Name, 20) = Files.Commands.No_Command,
            "compact sort-menu padding does not select a row");
         Assert
           (Files.UI.Bottom_Bar_Sort_Menu_Contains
              (Bar.Sort_Button_X, 0, 1000, Short_H,
               Files.Model.Sort_Name, 20),
            "visible compact sort-menu padding remains inside the clipped panel");
      end;
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

      --  A long disk-space label must not squeeze a complete compact count into
      --  an ellipsis; in that case the secondary free-space field yields.
      Files.UI.Split_Status_Region (200, 256, 168, TW, DX, FX, FW);
      Assert (TW = 256 and then FW = 0,
              "free space yields before truncating the compact count summary");

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
         Assert
           (Files.UI.Bottom_Bar_Command_At
              (Counts_X, Bottom_Y + 1, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Hidden_Files_Command,
            "the visible top of the counts area toggles hidden files");
         Assert
           (Files.UI.Bottom_Bar_Command_At
              (Counts_X, 799, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Hidden_Files_Command,
            "the visible bottom of the counts area toggles hidden files");
         Assert
           (Files.UI.Bottom_Bar_Command_At
              (Free_X, Bottom_Y + 1, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Free_Space_Display_Command,
            "the visible top of the free-space field toggles its display");
         Assert
           (Files.UI.Bottom_Bar_Command_At
              (Free_X, 799, 1000, 800, Snap.Sort_Field, Free_W, 20)
              = Files.Commands.Toggle_Free_Space_Display_Command,
            "the visible bottom of the free-space field toggles its display");
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

   --  In bar mode the free field draws a track (Input_Color) with a blue
   --  (Selection_Color) core whose width is the used fraction, and no text.
   procedure Test_Space_Bar_Renders (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Draw.Render_Color;
      Snap     : View_Snapshot := Sample_Snapshot (5, Files.Types.Details);
      Used_Sfx : constant String := Files.Localization.Text ("status.used_space.suffix");
      Free_Sfx : constant String := Files.Localization.Text ("status.free_space.suffix");
   begin
      Snap.Free_Space_Known := True;
      Snap.Total_Space_Bytes := 100;
      Snap.Free_Space_Bytes := 40;  --  60% used
      Snap.Info_Pane_Open := False;
      Snap.Show_Space_Bar := True;
      Snap.Command_Enabled (Files.Commands.Toggle_Free_Space_Display_Command) := True;
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Track_X, Track_Y, Track_W, Fill_W : Natural := 0;
         Has_Track : Boolean := False;
         Has_Used, Has_Free : Boolean := False;
      begin
         --  The track is the bottom-bar Input_Color rect; the fill is the
         --  Selection_Color rect at the same origin.
         for R of Frame.Rectangles loop
            if R.Y >= Bottom_Y and then R.Color = Guikit.Draw.Input_Color then
               Track_X := R.X; Track_Y := R.Y; Track_W := R.Width; Has_Track := True;
            end if;
         end loop;
         for R of Frame.Rectangles loop
            if R.Color = Guikit.Draw.Selection_Color
              and then R.X = Track_X and then R.Y = Track_Y
            then
               Fill_W := R.Width;
            end if;
         end loop;
         for C of Frame.Text loop
            if C.Y >= Bottom_Y then
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Used_Sfx) > 0 then
                  Has_Used := True;
               end if;
               if Ada.Strings.Fixed.Index (To_String (C.Text), " " & Free_Sfx) > 0 then
                  Has_Free := True;
               end if;
            end if;
         end loop;
         Assert (Has_Track and then Track_W > 0, "space bar draws a track");
         Assert (Fill_W > 0 and then Fill_W < Track_W, "the used fill is a fraction of the track");
         Assert (abs (Fill_W * 100 / Track_W - 60) <= 8, "the fill width is ~60% (the used fraction)");
         Assert (not Has_Used and then not Has_Free, "bar mode shows no free/used suffix text");
      end;

      --  When 10% or less of the disk is free, the fill warns in red, not blue.
      Snap.Free_Space_Bytes := 5;  --  5% free (95% used)
      declare
         Layout   : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 1000, 800, 20);
         Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 1000, 800, 20);
         Bottom_Y : constant Natural := Layout.Height - Layout.Bottom_Bar_Height;
         Track_X, Track_Y : Natural := 0;
         Has_Red, Has_Blue : Boolean := False;
      begin
         for R of Frame.Rectangles loop
            if R.Y >= Bottom_Y and then R.Color = Guikit.Draw.Input_Color then
               Track_X := R.X; Track_Y := R.Y;
            end if;
         end loop;
         for R of Frame.Rectangles loop
            if R.X = Track_X and then R.Y = Track_Y then
               if R.Color = Guikit.Draw.Error_Text_Color then
                  Has_Red := True;
               elsif R.Color = Guikit.Draw.Selection_Color then
                  Has_Blue := True;
               end if;
            end if;
         end loop;
         Assert (Has_Red, "the fill is red when 10% or less is free");
         Assert (not Has_Blue, "the fill is not blue when free space is low");
      end;

      --  Host capacity values are signed machine-wide integers.  Comparing the
      --  low-space threshold must not multiply a large valid value by ten.
      Snap.Total_Space_Bytes := Long_Long_Integer'Last;
      Snap.Free_Space_Bytes := Long_Long_Integer'Last;
      declare
         Frame : constant Frame_Commands :=
           Build_Frame_Commands (Snap, 1000, 800, 20);
      begin
         Assert (not Frame.Rectangles.Is_Empty,
                 "extreme capacity values render without threshold overflow");
      end;
   end Test_Space_Bar_Renders;

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

   procedure Test_Marquee_Auto_Scroll_Step (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  A rows region from y=100 to y=500, rows 20px tall (so a 20px edge zone).
      Top    : constant Integer := 100;
      Bottom : constant Integer := 500;
      LH     : constant Positive := 20;

      function Step (Cursor_Y : Integer) return Integer is
        (Marquee_Auto_Scroll_Step (Cursor_Y, Top, Bottom, LH));
   begin
      --  Comfortably inside the region: no scroll.
      Assert (Step (300) = 0, "a pointer well inside the region does not scroll");
      Assert (Step (Top + LH) = 0, "the pointer just past the top edge zone does not scroll");
      Assert (Step (Bottom - LH) = 0, "the pointer just past the bottom edge zone does not scroll");

      --  Within the edge zone or beyond: scroll toward that edge, accelerating.
      Assert (Step (Top + LH - 1) = -1, "entering the top edge zone scrolls up by one line");
      Assert (Step (Top) = -2, "at the top edge the upward step grows");
      Assert (Step (Bottom - LH + 1) = 1, "entering the bottom edge zone scrolls down by one line");
      Assert (Step (Bottom) = 2, "at the bottom edge the downward step grows");

      --  Far past an edge (pointer dragged outside the window): capped at 4.
      Assert (Step (-1000) = -4, "far above the region the upward step is capped");
      Assert (Step (5000) = 4, "far below the region the downward step is capped");

      --  Directions are opposite and symmetric about the region.
      Assert (Step (50) < 0 and then Step (600) > 0, "above scrolls up, below scrolls down");

      --  Coordinate-limit input is still capped instead of overflowing.
      Assert
        (Marquee_Auto_Scroll_Step
           (Integer'First, Integer'Last, Integer'Last, Positive'Last) = -4,
         "extreme top-edge arithmetic remains capped");
      Assert
        (Marquee_Auto_Scroll_Step
           (Integer'Last, Integer'First, Integer'First, Positive'Last) = 4,
         "extreme bottom-edge arithmetic remains capped");
   end Test_Marquee_Auto_Scroll_Step;

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

   procedure Test_Drag_Preview_Uses_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Base : constant Frame_Commands := Build_Frame_Commands (Snap, 640, 480, 20);
      Drag : constant Frame_Commands :=
        Build_Frame_Commands
          (Snap, 640, 480, 20,
           Drag_Item_Index => 1,
           Drag_X          => 620,
           Drag_Y          => 460,
           Has_Drag        => True);
      Found_Icon : Boolean := False;
      Found_Name : Boolean := False;
      Widths  : constant array (Positive range <>) of Natural := [1, 7, 40, 120, 640];
      Heights : constant array (Positive range <>) of Natural := [1, 7, 20, 44, 100];
   begin
      Assert
        (Natural (Drag.Rectangles.Length) = Natural (Base.Rectangles.Length),
         "the drag preview adds no panel geometry to the base layer");
      Assert
        (Natural (Drag.Overlay_Rectangles.Length) > Natural (Base.Overlay_Rectangles.Length),
         "the drag preview panel is emitted in the overlay layer");
      for Icon of Drag.Icons loop
         Found_Icon := Found_Icon or else Icon.Overlay;
      end loop;
      for Command of Drag.Overlay_Text loop
         Found_Name := Found_Name or else To_String (Command.Text) = "item 1";
      end loop;
      Assert (Found_Icon, "the dragged item's icon is emitted in the overlay layer");
      Assert (Found_Name, "the dragged item's name is emitted in the overlay layer");

      for Width of Widths loop
         for Height of Heights loop
            declare
               Frame : constant Frame_Commands :=
                 Build_Frame_Commands
                   (Snap, Width, Height, 20,
                    Drag_Item_Index => 1,
                    Drag_X          => Width - 1,
                    Drag_Y          => Height - 1,
                    Has_Drag        => True);
            begin
               for Rect of Frame.Overlay_Rectangles loop
                  Assert
                    (Rect.Width > 0 and then Rect.Height > 0
                     and then Rect.X + Rect.Width <= Width
                     and then Rect.Y + Rect.Height <= Height,
                     "compact drag-preview rectangles stay inside the framebuffer");
               end loop;
               for Icon of Frame.Icons loop
                  if Icon.Overlay then
                     Assert
                       (Icon.X + Icon.Size <= Width and then Icon.Y + Icon.Size <= Height,
                        "compact drag-preview icons stay inside the framebuffer");
                  end if;
               end loop;
               for Command of Frame.Overlay_Text loop
                  Assert
                    (Command.X + Command.Width <= Width
                     and then Command.Y + Command.Height <= Height,
                     "compact drag-preview text stays inside the framebuffer");
               end loop;
            end;
         end loop;
      end loop;
   end Test_Drag_Preview_Uses_Overlay;

end Files_Suite.Rendering;
