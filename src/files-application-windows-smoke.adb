with Ada.Strings;
with Ada.Strings.Fixed;

with Files.File_System;

package body Files.Application.Windows.Smoke is
   use Ada.Strings.Unbounded;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.View_Mode;
   use type Glfw.Size;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_32;

   --  Pristine per-window state captured before the multi-scenario live smoke
   --  so every scenario starts from an identical baseline and any framebuffer
   --  difference is attributable to the applied scenario alone.
   type Scenario_Base_State is record
      Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Font     : Positive := 16;
   end record;

   package Scenario_Base_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Scenario_Base_State);

   function Headless_Smoke_Test
     (Startup : Startup_Result)
      return Boolean is
   begin
      for Startup_Window of Startup.Windows loop
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Startup_Window.Model, Startup.Settings);
            Frame    : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => 320,
                 Height      => 240,
                 Line_Height => 20);
            Text     : Files.Rendering.Text_Renderer;
            Text_Status : constant Files.Rendering.Text_Render_Status :=
              Files.Rendering.Initialize_Text
                (Renderer    => Text,
                 Font_Path   => Files.Rendering.Font_Path_For_Frame (Frame),
                 Pixel_Size  => 16,
                 Cell_Width  => 12,
                 Cell_Height => 20);
            Glyphs : constant Files.Rendering.Text_Render_Result :=
              Files.Rendering.Build_Text_Glyphs (Text, Frame);
         begin
            if Frame.Layout.Width /= 320
              or else Frame.Layout.Height /= 240
              or else Frame.Rectangles.Is_Empty
              or else Text_Status /= Files.Rendering.Text_Render_Success
              or else Glyphs.Status /= Files.Rendering.Text_Render_Success
              or else Glyphs.Glyphs.Is_Empty
              or else To_String (Snapshot.Current_Path) = ""
            then
               return False;
            end if;
         end;
      end loop;

      return True;
   exception
      when others =>
         return False;
   end Headless_Smoke_Test;

   function Headless_Render_Quality_Report
     (Startup : Startup_Result;
      Width   : Natural := 1024;
      Height  : Natural := 768)
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
      return Files.File_System.Item_Vectors.Vector
   is
      Parent : constant String := Files.Model.Current_Path (Model);
      Items  : Files.File_System.Item_Vectors.Vector;
   begin
      for Index in 1 .. Scenario_Overflow_Item_Count loop
         declare
            Suffix : constant String :=
              Ada.Strings.Fixed.Trim (Integer'Image (Index), Ada.Strings.Left);
            Name   : constant String := "smoke-item-" & Suffix;
         begin
            Items.Append
              (Files.File_System.Directory_Item'
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
   --  Rendering caches and the font renderer are invalidated so the next frame
   --  is rebuilt from the scenario state.
   procedure Prepare_Scenario
     (Runtime  : in out Runtime_Window;
      Base     : Scenario_Base_State;
      Scenario : Live_Smoke_Scenario) is
   begin
      Runtime.Model := Base.Model;
      Runtime.Settings := Base.Settings;
      Runtime.Synced_Settings := Base.Settings;
      Runtime.Font_Pixel_Size := Base.Font;
      Runtime.Text_Ready := False;
      Runtime.Text_Glyph_Key := Null_Unbounded_String;
      Runtime.Frame_Cache_Valid := False;
      Runtime.Snapshot_Valid := False;
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
     (Width  : Natural := 1024;
      Height : Natural := 768)
      return Live_Smoke_Plan
   is
      Caps : constant Desktop_Capabilities := Runtime_Capabilities;
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
      if not Plan.Can_Run then
         return
           (Attempted          => False,
            Window_Created     => False,
            Frame_Rendered     => False,
            Frames_Attempted   => 0,
            Frames_Presented   => 0,
            Input_Polled       => False,
            Closed_Cleanly     => False,
            Skipped_By_Plan    => True,
            Last_Status        => Guikit.Vulkan.Vulkan_Not_Initialized,
            Last_Vk_Result     => 0,
            Framebuffer_Readback_Ready => False,
            Last_Framebuffer_Hash => 0,
            Last_Framebuffer_Bytes => 0,
            Framebuffer_Analysis => (others => <>),
            Framebuffer_Passed => False,
            Vulkan_Device_Ready => False,
            Scenario_Results   => [others => <>],
            Error_Key          => Plan.Reason_Key);
      end if;

      return
        (Attempted          => False,
         Window_Created     => False,
         Frame_Rendered     => False,
         Frames_Attempted   => 0,
         Frames_Presented   => 0,
         Input_Polled       => False,
         Closed_Cleanly     => False,
         Skipped_By_Plan    => False,
         Last_Status        => Guikit.Vulkan.Vulkan_Not_Initialized,
         Last_Vk_Result     => 0,
         Framebuffer_Readback_Ready => False,
         Last_Framebuffer_Hash => 0,
         Last_Framebuffer_Bytes => 0,
         Framebuffer_Analysis => (others => <>),
         Framebuffer_Passed => False,
         Vulkan_Device_Ready => False,
         Scenario_Results   => [others => <>],
         Error_Key          => To_Unbounded_String ("runtime.smoke.requires_live_harness"));
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
      then
         return Live_Smoke_Pass;
      else
         return Live_Smoke_Fail;
      end if;
   end Gate_Outcome;

end Files.Application.Windows.Smoke;
