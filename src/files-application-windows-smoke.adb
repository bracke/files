with Files.Preference_Types;
with Files.Window_Polls;
with Files.UI_Types;
with Ada.Real_Time;
with Files.Fonts;
with Files.Items;
with Ada.Strings;
with Ada.Strings.Fixed;

with Files.File_System;
with Files.Model.Selection;

package body Files.Application.Windows.Smoke is
   use Ada.Strings.Unbounded;
   use type Files.Rendering.Text.Text_Render_Status;
   use type Files.UI_Types.Focus_Target;
   use type Files.Preference_Types.View_Mode;
   use type Glfw.Size;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_32;

   --  Pristine per-window state captured before the multi-scenario live smoke
   --  so every scenario starts from an identical baseline and any framebuffer
   --  difference is attributable to the applied scenario alone.
   type Scenario_Base_State is record
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
   end record;

   package Scenario_Base_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Scenario_Base_State);

   --  Model with the host's samples taken, as a window takes them before
   --  each frame (Render_Window): the free-space text and owner names are
   --  drawn from them.
   function Sampled (Model : Files.Model.Window_Model) return Files.Model.Window_Model is
      Result : Files.Model.Window_Model := Model;
   begin
      Files.Window_Polls.Sample_Volume_Space (Result);
      Files.Window_Polls.Sample_Account_Names (Result);
      return Result;
   end Sampled;

   --  The line height a window draws Settings' font size at.
   function Line_Height_For (Settings : Files.Settings.Settings_Model) return Positive is
     (Files.Rendering.Cell_Height_For (Settings.Font_Pixel_Size));

   --  What Frame, built from Snapshot, came to: its text drawn through the
   --  window's own text path (Files.Rendering.Text.Window_Text) at Settings'
   --  font size, and its Vulkan submission.
   function Frame_Check
     (Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check
   is
      Text      : Files.Rendering.Text.Window_Text;
      Font_Path : constant String := Files.Fonts.Default_Font_Path;
   begin
      Files.Rendering.Text.Ensure_Loaded (Text, Font_Path, Settings.Font_Pixel_Size, Ada.Real_Time.Clock);
      declare
         Glyphs : constant Files.Rendering.Text.Text_Render_Result :=
           Files.Rendering.Text.Glyphs_For (Text, Frame, Ada.Real_Time.Clock);
         Batch  : constant Guikit.Vulkan.Submission_Batch :=
           Guikit.Vulkan.Build_Submission
             (Rectangles         => Frame.Rectangles,
              Triangles          => Frame.Triangles,
              Icons              => Frame.Icons,
              Overlay_Rectangles => Frame.Overlay_Rectangles,
              Layout             => Frame.Layout,
              Theme              => Frame.Theme_Palette,
              Text               => Glyphs);
      begin
         return
           (Size_Matches   => Frame.Layout.Width = Width and then Frame.Layout.Height = Height,
            Has_Path       => Length (Snapshot.Current_Path) > 0,
            Rectangles     => Natural (Frame.Rectangles.Length),
            Glyphs         => Natural (Glyphs.Glyphs.Length),
            Missing_Glyphs => Glyphs.Missing_Glyph_Count,
            Vertices       => Natural (Batch.Vertices.Length),
            Text_Rendered  =>
              Glyphs.Status = Files.Rendering.Text.Text_Render_Success
              and then not Glyphs.Glyphs.Is_Empty,
            Font_Path      => To_Unbounded_String (Font_Path));
      end;
   end Frame_Check;

   function Check_Window_Frame
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Width    : Natural;
      Height   : Natural)
      return Window_Frame_Check
   is
      Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Sampled (Model), Settings);
      Frame    : constant Files.Rendering.Frame_Commands :=
        Files.Rendering.Build_Frame_Commands
          (Snapshot    => Snapshot,
           Width       => Width,
           Height      => Height,
           Line_Height => Line_Height_For (Settings),
           Pointer => (Hover_X => 5, Hover_Y => 5, Has_Hover => Width > 0 and then Height > 0, others => <>));
   begin
      return Frame_Check (Snapshot, Frame, Settings, Width, Height);
   end Check_Window_Frame;

   function Headless_Render_Quality_Report
     (Startup : Startup_Result;
      Width   : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height  : Natural := Files.Rendering.Layouts.Default_Window_Height)
      return Headless_Render_Quality_Result
 is separate;

   --  Number of synthetic items injected for the scrolled scenario. Chosen to
   --  overflow the smoke window's main view at any plausible column count so
   --  the scrolled render is guaranteed to differ from the default frame.
   Scenario_Overflow_Item_Count : constant Positive := 800;

   --  Minimum visible item count that reliably fills the whole smoke window at
   --  any view mode/font. A startup directory sparser than this (e.g. a home
   --  folder with hidden files off) leaves the lower frame empty, which the
   --  structural verdict -- every horizontal band must hold content -- reads as
   --  a failure. The baseline seeds a synthetic grid below this count so the
   --  smoke's structural check does not depend on the real directory contents.
   Scenario_Minimum_Fill_Items : constant Positive := 150;

   --  Main-view scroll offset applied once the overflowing list is in place.
   Scenario_Scroll_Lines : constant Positive := 40;

   function Scenario_Name
     (Scenario : Live_Smoke_Scenario)
      return String is
   begin
      case Scenario is
         when Scenario_Default =>
            return "default";
         when Scenario_Selection =>
            return "selection";
         when Scenario_Scrolled =>
            return "scrolled";
         when Scenario_Context_Menu =>
            return "context_menu";
         when Scenario_Palette =>
            return "palette";
         when Scenario_Root_Selector =>
            return "root_selector";
         when Scenario_Sort_Menu =>
            return "sort_menu";
         when Scenario_Tree_Panel =>
            return "tree_panel";
         when Scenario_Settings =>
            return "settings";
         when Scenario_Settings_Tab_2 =>
            return "settings_tab2";
         when Scenario_Settings_Tab_3 =>
            return "settings_tab3";
         when Scenario_Settings_Tab_4 =>
            return "settings_tab4";
         when Scenario_Settings_Tab_5 =>
            return "settings_tab5";
         when Scenario_Settings_Tab_6 =>
            return "settings_tab6";
         when Scenario_Settings_Tab_7 =>
            return "settings_tab7";
         when Scenario_Settings_Light =>
            return "settings_light";
         when Scenario_Settings_Large_Font =>
            return "settings_large_font";
         when Scenario_Settings_Keyboard =>
            return "settings_keyboard";
         when Scenario_Large_Font =>
            return "large_font";
         when Scenario_Light_Theme =>
            return "light_theme";
         when Scenario_Details_View =>
            return "details_view";
         when Scenario_Quick_Look =>
            return "quick_look";
         when Scenario_Quick_Look_Image =>
            return "quick_look_image";
      end case;
   end Scenario_Name;

   function Scenario_Passed
     (Outcomes : Scenario_Outcome_Array;
      Scenario : Live_Smoke_Scenario)
      return Boolean is
   begin
      if not Outcomes (Scenario).Passed then
         return False;
      end if;

      if Scenario /= Scenario_Default
        and then Outcomes (Scenario).Hash = Outcomes (Scenario_Default).Hash
      then
         return False;
      end if;

      --  A layout-derived region assertion that ran but found no ink means a
      --  UI element is missing from its computed pixel position (a coordinate
      --  or DPI-scaling regression), even though the structural Analyze passed.
      if Outcomes (Scenario).Region_Checked
        and then not Outcomes (Scenario).Region_Ink_Present
      then
         return False;
      end if;

      if Outcomes (Scenario).Keys_Checked
        and then Outcomes (Scenario).Keys_Failed_Step /= 0
      then
         return False;
      end if;

      return True;
   end Scenario_Passed;

   function Scenarios_Verdict
     (Outcomes : Scenario_Outcome_Array)
      return Boolean is
   begin
      for Scenario in Live_Smoke_Scenario loop
         if not Scenario_Passed (Outcomes, Scenario) then
            return False;
         end if;
      end loop;

      return True;
   end Scenarios_Verdict;

   --  Build a synthetic overflowing item list rooted at the model's current
   --  path so the scrolled scenario has enough rows to scroll through.
   function Scenario_Overflow_Items
     (Model : Files.Model.Window_Model)
      return Files.Items.Item_Vectors.Vector
   is
      Parent : constant String := Files.Model.Current_Path (Model);
      Items  : Files.Items.Item_Vectors.Vector;
   begin
      for Index in 1 .. Scenario_Overflow_Item_Count loop
         declare
            Suffix : constant String :=
              Ada.Strings.Fixed.Trim (Integer'Image (Index), Ada.Strings.Left);
            Name   : constant String := "smoke-item-" & Suffix;
         begin
            Items.Append
              (Files.Items.Directory_Item'
                 (Name        => To_Unbounded_String (Name),
                  Full_Path   => To_Unbounded_String (Parent & "/" & Name),
                  Parent_Path => To_Unbounded_String (Parent),
                  Hidden      => False,
                  Kind        => Files.Types.Regular_File_Item,
                  Filetype    => To_Unbounded_String ("text/plain"),
                  Icon_Id     => To_Unbounded_String ("text"),
                  others      => <>));
         end;
      end loop;

      return Items;
   end Scenario_Overflow_Items;

   --  Apply one live smoke scenario's state to a runtime window in place. The
   --  caller resets the window to its captured baseline before each call, so
   --  each scenario mutates only from the pristine startup state.
   procedure Apply_Scenario
     (Runtime  : in out Runtime_Window;
      Scenario : Live_Smoke_Scenario)
 is separate;

   --  Drive the settings panel with a scripted key sequence queued exactly as
   --  the window's key callback queues presses, so each key takes the live
   --  dispatch path. A frame is rendered after every key.
   --
   --  @param Runtime Window to drive, in its scenario baseline state.
   --  @param Failed_Step First step whose expected effect did not happen, or 0.
   procedure Drive_Settings_Keys
     (Runtime     : in out Runtime_Window;
      Failed_Step : out Natural)
 is separate;

   --  Reset a runtime window to a captured baseline and apply one scenario.
   --  The frame caches are invalidated so the next frame is rebuilt from the
   --  scenario state; a font size the scenario changed is taken up there
   --  (Render_Window.Read_Window_State), as for any settings change.
   procedure Prepare_Scenario
     (Runtime  : in out Runtime_Window;
      Base     : Scenario_Base_State;
      Scenario : Live_Smoke_Scenario) is
   begin
      Runtime.Model := Base.Model;
      Runtime.Settings := Base.Settings;
      Runtime.Synced_Settings_Revision := Files.Model.Settings_Revision (Runtime.Model);
      Runtime.Frame_Cache_Valid := False;
      Runtime.View.Snapshot_Valid := False;
      --  Every scenario starts from the same model, so its revision repeats:
      --  the overlays' caches, keyed on it, are dropped with the frame's.
      Runtime.Palette_Overlay_Built := False;
      Runtime.Settings_Overlay_Built := False;
      Apply_Scenario (Runtime, Scenario);
   end Prepare_Scenario;

   --  A layout-derived pixel rectangle whose ink presence in the read-back
   --  framebuffer proves a specific UI element rendered at its computed
   --  position. Valid is False for scenarios without a region assertion.
   type Region_Rect is record
      Valid : Boolean := False;
      X     : Natural := 0;
      Y     : Natural := 0;
      W     : Natural := 0;
      H     : Natural := 0;
   end record;

   --  Compute the layout-derived region a scenario asserts against the frame.
   --
   --  The rectangle is produced by the same layout functions the live renderer
   --  uses (Build_Snapshot + Calculate_Layout + Calculate_Item_Layout) at the
   --  scenario's own model/settings/font and the actual framebuffer size, so it
   --  indexes the read-back framebuffer directly. Only scenarios with a stable,
   --  always-present element carry a check.
   function Scenario_Region
     (Runtime  : Runtime_Window;
      Scenario : Live_Smoke_Scenario;
      Frame_W  : Natural;
      Frame_H  : Natural)
      return Region_Rect
 is separate;

   function Live_Window_Smoke_Plan
     (Width  : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height : Natural := Files.Rendering.Layouts.Default_Window_Height)
      return Live_Smoke_Plan is
     (Live_Window_Smoke_Plan (Runtime_Capabilities, Width, Height));

   function Live_Window_Smoke_Plan
     (Caps   : Desktop_Capabilities;
      Width  : Natural := Files.Rendering.Layouts.Default_Window_Width;
      Height : Natural := Files.Rendering.Layouts.Default_Window_Height)
      return Live_Smoke_Plan is
   begin
      return
        (Can_Run          => Caps.Live_Window_Smoke_Ready,
         Needs_Display    => True,
         Needs_Vulkan     => True,
         Width            => Width,
         Height           => Height,
         Frame_Count      => 2,
         Input_Poll_Count => 1,
         Reason_Key       =>
           To_Unbounded_String
             ((if not Caps.Display_Available then "runtime.smoke.no_display"
               elsif not Caps.Vulkan_Available then "runtime.smoke.no_vulkan"
             else "runtime.smoke.ready")));
   end Live_Window_Smoke_Plan;

   function Evaluate_Live_Window_Smoke
     (Plan : Live_Smoke_Plan)
      return Live_Smoke_Result is
   begin
      --  Nothing was attempted either way: only why differs.
      if not Plan.Can_Run then
         return (Skipped_By_Plan => True, Error_Key => Plan.Reason_Key, others => <>);
      end if;

      return
        (Skipped_By_Plan => False,
         Error_Key       => To_Unbounded_String ("runtime.smoke.requires_live_harness"),
         others          => <>);
   end Evaluate_Live_Window_Smoke;

   function Run_Live_Window_Smoke
     (Startup : Startup_Result;
      Plan    : Live_Smoke_Plan)
      return Live_Smoke_Result
 is separate;

   function Gate_Outcome
     (Result : Live_Smoke_Result)
      return Live_Smoke_Gate is
   begin
      if Result.Skipped_By_Plan or else not Result.Attempted then
         return Live_Smoke_Skip;
      elsif not Result.Vulkan_Device_Ready then
         --  A window opened but no usable Vulkan device/ICD initialized. That
         --  is an environment gap (no working driver), not a display defect,
         --  so it is a skip rather than a failure.
         return Live_Smoke_Skip;
      elsif Result.Framebuffer_Passed
        and then Result.Framebuffer_Readback_Ready
        and then Result.Closed_Cleanly
        and then Result.Loop_Failures = 0
        and then Result.Loop_Drew_Input
        and then Result.Resize_Drawn
      then
         return Live_Smoke_Pass;
      else
         return Live_Smoke_Fail;
      end if;
   end Gate_Outcome;

end Files.Application.Windows.Smoke;
