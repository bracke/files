with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Hostkit.Host;
with Ada.Directories;
with Ada.Environment_Variables;
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
with Interfaces;
with Guikit.Draw;
with Guikit.Shared_Bytes;
with Files.Rendering;
with Files.Rendering.Hit;
with Files.Accessibility;
with Files.Settings;
with Files_Suite.Support;
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
   use type Guikit.Draw.Render_Color;
   use type Files.Events.Input_Action_Kind;
   use type Files.Types.Focus_Target;
   use type A11y.Results.Status_Code;
   use type System.Address;

   type Rendering_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (T : Rendering_Test_Case) return AUnit.Message_String;
   overriding procedure Register_Tests (T : in out Rendering_Test_Case);

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Reveal_Scroll_Shows_Item (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Snapshot_Key_Covers_Settings (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_A11y_Stop_Is_Final (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Item_Icons_Drawn_Once (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Icon_Atlas_Shared_Across_Frames (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Text_Pool_Evicts_Least_Recent (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Overlay_Suppresses_Background_Tooltips (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Root_Selector_Uses_Shadow_Color (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Conflict_Has_Modal_Backdrop (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Input_Scroll_Keeps_Caret_Visible (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Floating_Menus_Have_Elevation (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Info_And_Root_Selector_Close_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Folder_Tree_Close_Button_Layering (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Scrolled_Tree_Rows_Map_To_Source (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Tree_Pick_Buttons_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Dialog_Overlays_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Paste_Progress_Overlay_Bar (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Compact_Blocking_Dialogs_Fit (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Column_Customization (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Group_Header_Rows (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Header_Separator_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Detail_Separators_Within_Content (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Whole_Content_Item_Layout (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Shared_Text_Renderer_Invalidates_Glyphs (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Invalid_UTF8_Names (T : in out AUnit.Test_Cases.Test_Case'Class);
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
   procedure Test_Localized_Text_Follows_Locale_Change (T : in out AUnit.Test_Cases.Test_Case'Class);

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
        (T, Test_Reveal_Scroll_Shows_Item'Access,
         "the selection scrolls into view whole in every view mode, and Page Down moves by the rows in view");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Snapshot_Key_Covers_Settings'Access,
         "every setting the snapshot reads is part of the key that decides when a frame can be reused");
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
        (T, Test_A11y_Stop_Is_Final'Access,
         "Screen reader: Stop is final until Start");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Item_Icons_Drawn_Once'Access,
         "Item icons are drawn once, as vectors");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Icon_Atlas_Shared_Across_Frames'Access,
         "An unchanged icon atlas is shared, also between two windows");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Text_Pool_Evicts_Least_Recent'Access,
         "The text renderer pool evicts the one used least recently");
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
        (T, Test_Info_And_Root_Selector_Close_Buttons'Access,
         "the info pane and root selector each emit a close-button accessibility node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Folder_Tree_Close_Button_Layering'Access,
         "the folder tree emits a close button that modal layers above it cover");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Scrolled_Tree_Rows_Map_To_Source'Access,
         "a scrolled destination tree maps clipped rows to their source rows above the picker footer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Tree_Pick_Buttons_Hit_Test'Access,
         "the folder-tree destination picker lays out and hit-tests its Choose/Cancel bar");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Dialog_Overlays_Expose_Close_Button'Access,
         "quick look, label picker and paste-conflict overlays each emit a close-button node");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Paste_Progress_Overlay_Bar'Access,
         "the paste-progress overlay exposes Cancel, a proportional bar and a modal backdrop");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Compact_Blocking_Dialogs_Fit'Access,
         "blocking dialogs stay inside a short, narrow framebuffer");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Overlay_Content'Access,
         "the quick look overlay emits its dialog panel and previewed content");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Quick_Look_Image_High_Res'Access,
         "a quick look image preview uses the full-resolution image and aspect ratio");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Localized_Text_Follows_Locale_Change'Access,
         "localized text remembered for one locale follows a change of LC_ALL to another and back");
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
        (T, Test_Whole_Content_Item_Layout'Access,
         "the whole-content item layout places scrolled-off rows where a scrolling marquee finds them");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Shared_Text_Renderer_Invalidates_Glyphs'Access,
         "glyphs from a shared text renderer are rebuilt once another window changed its atlas");
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
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Invalid_UTF8_Names'Access,
         "a file name that is not valid UTF-8 lists, renders, renames and deletes");
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

   procedure Test_Details_Header_Text_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Toolbar_Text_Optically_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compact_Breadcrumbs_Stay_In_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compact_Empty_State_Stays_In_View
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Empty_Info_Pane_Message (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Info_Pane_Content_Clipped (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scope_Chip_Has_Own_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Filetype_Labels_Omit_Document (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Snapshot_Key_Covers_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Reveal_Scroll_Shows_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Layout_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Main_View_Scroll_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Command_Palette_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Frame_Rendering_Invariants (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compact_Frame_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Compact_Overlay_Commands_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Extreme_Size_Saturation (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Extension_Label_Extreme_Height
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

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

   procedure Test_Large_Icons_Rename_Caret (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Large_Icon_Badges_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Multi_Rename_Fields_And_Carets (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Show_Extensions_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Caret_Click_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Caret_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Click_Translation_Behavior (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Text_Glyph_Rasterization (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Emoji_Draws_As_Colour_Icons (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Vulkan_Submission (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Bottom_Bar_Hidden_Count (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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
   procedure Test_Bottom_Bar_Free_Space (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Modified_Time_Is_Local (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_A11ykit_Tree_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_A11y_Stop_Is_Final (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Item_Icons_Drawn_Once (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Icon_Atlas_Shared_Across_Frames (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Text_Pool_Evicts_Least_Recent (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Selection_Summary (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Context_Menu_Suppresses_Item_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Overlay_Suppresses_Background_Tooltips
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Root_Selector_Uses_Shadow_Color
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Paste_Conflict_Has_Modal_Backdrop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Input_Scroll_Keeps_Caret_Visible (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Floating_Menus_Have_Elevation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Info_And_Root_Selector_Close_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Folder_Tree_Close_Button_Layering (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Scrolled_Tree_Rows_Map_To_Source (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Tree_Pick_Buttons_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Dialog_Overlays_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Paste_Progress_Overlay_Bar (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Compact_Blocking_Dialogs_Fit (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

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

   procedure Test_Quick_Look_Overlay_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Drawn_In_Overlay (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Label_Picker_Drawn_In_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Localized_Text_Follows_Locale_Change (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Quick_Look_Image_High_Res (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Theme_Palette_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (AUnit.Test_Cases.Test_Case_Access'(new Rendering_Test_Case));
      return Result;
   end Suite;

   procedure Test_Detail_Column_Customization (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detail_Separators_Within_Content (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Whole_Content_Item_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Shared_Text_Renderer_Invalidates_Glyphs (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Bottom_Bar_Text_Baseline (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sort_Button_Fits_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Sort_Label_Centered (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Free_Space_Separate_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Counts_Text_Uses_Active_Color (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Counts_Tooltip_Explains_Numbers (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Free_Space_Has_Tooltip (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Free_Space_Outside_Toggle_Hover (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Split_Status_Region (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Free_Space_Click_Toggles (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Used_Space_Label_After_Toggle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Space_Bar_Renders (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Counts_Compact_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detail_Column_Reorder_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detail_Group_Header_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Detail_Header_Separator_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Favorite_Star_Indicators (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Color_Label_Grid_Dots (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Marquee_Items_In_Rect (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Marquee_Auto_Scroll_Step (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Marquee_Frame_Draws_Rectangle (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Drag_Preview_Uses_Overlay
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is separate;

   procedure Test_Invalid_UTF8_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

end Files_Suite.Rendering;
