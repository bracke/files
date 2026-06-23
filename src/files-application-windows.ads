with Files.Controller;
with Files.Rendering.Vulkan;
with Glfw;
with Glfw.Input.Mouse;
with Interfaces;

--  GLFW-backed desktop window session for resolved startup windows.
package Files.Application.Windows is
   Desktop_Error : exception;

   type Desktop_Capabilities is record
      Display_Available       : Boolean := False;
      Vulkan_Available        : Boolean := False;
      Native_File_Dialogs     : Boolean := False;
      Headless_Rendering      : Boolean := True;
      Live_Window_Smoke_Ready : Boolean := False;
      Event_Translation_Model : Boolean := True;
      Focus_Runtime_Model     : Boolean := True;
      Resize_Runtime_Model    : Boolean := True;
      Scroll_Runtime_Model    : Boolean := True;
      Native_Drop_Callbacks   : Boolean := True;
      Native_Drop_Automation  : Boolean := False;
      Directory_Watch_Polling : Boolean := True;
      Native_File_Watching    : Boolean := True;
   end record;

   type Native_Drag_Automation_Profile is record
      Portable_GLFW_Automation        : Boolean := False;
      Native_Drop_Callbacks           : Boolean := True;
      Requires_OS_Event_Source        : Boolean := True;
      X11_Xdnd_Required               : Boolean := True;
      Wayland_Source_Protocol_Required : Boolean := True;
      Windows_Native_Injection_Required : Boolean := True;
      Macos_Native_Injection_Required : Boolean := True;
      Binding_Unit                    : UString;
   end record;

   type Native_File_Dialog_Mode is
     (Open_File_Dialog,
      Save_File_Dialog);

   type Native_File_Dialog_Request is record
      Mode               : Native_File_Dialog_Mode := Open_File_Dialog;
      Title_Key          : UString;
      Initial_Path       : UString;
      Suggested_Name     : UString;
      Required_Extension : UString;
   end record;

   type Native_File_Dialog_Result is record
      Supported     : Boolean := False;
      Attempted     : Boolean := False;
      Completed     : Boolean := False;
      Selected_Path : UString;
      Backend_Name  : UString;
      Error_Key     : UString;
   end record;

   type Live_Smoke_Plan is record
      Can_Run          : Boolean := False;
      Needs_Display    : Boolean := True;
      Needs_Vulkan     : Boolean := True;
      Width            : Natural := 1024;
      Height           : Natural := 768;
      Frame_Count      : Positive := 1;
      Input_Poll_Count : Positive := 1;
      Reason_Key       : UString;
   end record;

   type Live_Smoke_Result is record
      Attempted          : Boolean := False;
      Window_Created     : Boolean := False;
      Frame_Rendered     : Boolean := False;
      Frames_Attempted   : Natural := 0;
      Frames_Presented   : Natural := 0;
      Input_Polled       : Boolean := False;
      Closed_Cleanly     : Boolean := False;
      Skipped_By_Plan    : Boolean := True;
      Last_Status        : Files.Rendering.Vulkan.Vulkan_Status :=
        Files.Rendering.Vulkan.Vulkan_Not_Initialized;
      Last_Vk_Result     : Interfaces.Integer_32 := 0;
      Framebuffer_Readback_Ready : Boolean := False;
      Last_Framebuffer_Hash : Interfaces.Unsigned_32 := 0;
      Last_Framebuffer_Bytes : Natural := 0;
      Error_Key          : UString;
   end record;

   --  Create one GLFW window for each startup window and run until all close.
   --
   --  If GLFW cannot initialize or a native window cannot be created, this
   --  raises Desktop_Error after releasing any windows already created.
   --
   --  @param Startup Startup result containing window models to open.
   procedure Run
     (Startup : Startup_Result);

   --  Validate startup window models through the render pipeline without opening native windows.
   --
   --  @param Startup Startup result containing window models to validate.
   --  @return True when each startup window can produce a non-empty frame.
   function Headless_Smoke_Test
     (Startup : Startup_Result)
      return Boolean;

   --  Return whether a live desktop display appears available.
   --
   --  @return True when the environment advertises a display/session endpoint.
   function Live_Display_Available return Boolean;

   --  Return whether Vulkan support is advertised by GLFW.
   --
   --  @return True when GLFW reports Vulkan support after initialization.
   function Vulkan_Runtime_Available return Boolean;

   --  Return desktop runtime capabilities observable without opening a window.
   --
   --  @return Display, Vulkan, and smoke-test readiness flags.
   function Runtime_Capabilities return Desktop_Capabilities;

   --  Return the native blocker profile for OS drag-event automation.
   --
   --  GLFW provides file-drop callbacks but not portable synthesis of external
   --  drag events. This profile names the native backends required for real
   --  automation so capability reporting stays explicit.
   --
   --  @return Structured native drag automation capability and blocker metadata.
   function Native_Drag_Automation_Profile_Of_Current_Runtime
      return Native_Drag_Automation_Profile;

   --  Return whether a controller result should continue through runtime settings-path handling.
   --
   --  @param Result Controller result produced by pure command routing.
   --  @return True when runtime should provide settings path or native dialog behavior.
   function Runtime_Should_Resolve_Settings_Path
     (Result : Files.Controller.Controller_Result)
      return Boolean;

   --  Accumulate a fractional scroll offset into whole scroll lines.
   --
   --  @param Remainder Fractional offset carried from previous callbacks.
   --  @param Offset New GLFW-style scroll offset to add.
   --  @return Whole scroll lines produced by the accumulated offset.
   function Accumulate_Scroll_Offset
     (Remainder : in out Long_Float;
      Offset    : Long_Float)
      return Integer;

   --  Add pending scroll line counts using saturation.
   --
   --  @param Current Pending scroll lines already queued.
   --  @param Change Newly accumulated scroll lines.
   --  @return Saturated sum of current and new scroll lines.
   function Add_Pending_Scroll
     (Current : Integer;
      Change  : Integer)
      return Integer;

   --  Encode a GLFW character callback value for the byte-oriented text controller.
   --
   --  Control characters and invalid Unicode scalar values are ignored.
   --
   --  @param Char Character callback value reported by GLFW.
   --  @return UTF-8 bytes to append to focused text input, or an empty string.
   function Text_Input_Bytes
     (Char : Wide_Wide_Character)
      return String;

   --  Scale a window-relative mouse coordinate into framebuffer coordinates.
   --
   --  @param Value Mouse coordinate in the source window dimension.
   --  @param Source Source window dimension.
   --  @param Target Target framebuffer dimension.
   --  @return Clamped target coordinate, or zero for invalid dimensions.
   function Scale_Coordinate
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural;

   --  Return whether native file dialogs are available in this build/runtime.
   --
   --  @return True when the desktop backend can open OS file dialogs.
   function Native_File_Dialogs_Available return Boolean;

   --  Return whether a native file dialog mode is available in this build/runtime.
   --
   --  @param Mode Dialog mode to check.
   --  @return True when the desktop backend can open that dialog mode.
   function Native_File_Dialog_Mode_Available
     (Mode : Native_File_Dialog_Mode)
      return Boolean;

   --  Evaluate native file dialog support without opening a native dialog.
   --
   --  @param Request Dialog request to evaluate.
   --  @return Structured support result for tests and command preflight.
   function Evaluate_Native_File_Dialog
     (Request : Native_File_Dialog_Request)
      return Native_File_Dialog_Result;

   --  Open a native file dialog when supported.
   --
   --  The first implementation is conservative and returns a localized
   --  unavailable result when no native backend is linked.
   --
   --  @param Request Dialog request to execute.
   --  @return Structured dialog result.
   function Open_Native_File_Dialog
     (Request : Native_File_Dialog_Request)
      return Native_File_Dialog_Result;

   --  Build the native open-file dialog request for settings import.
   --
   --  @param Settings_Path Current central settings file path.
   --  @return Dialog request using the settings path as initial location.
   function Settings_Import_Dialog_Request
     (Settings_Path : String)
      return Native_File_Dialog_Request;

   --  Build the native save-file dialog request for settings export.
   --
   --  @param Settings_Path Current central settings file path.
   --  @return Dialog request using the settings path as initial location.
   function Settings_Export_Dialog_Request
     (Settings_Path : String)
      return Native_File_Dialog_Request;

   --  Resolve the settings path after a native dialog attempt.
   --
   --  @param Configured_Path Existing central settings file path.
   --  @param Dialog_Result Native dialog result to apply.
   --  @return Selected dialog path when completed, otherwise Configured_Path.
   function Settings_Path_After_Dialog
     (Configured_Path : String;
      Dialog_Result   : Native_File_Dialog_Result)
      return UString;

   --  Resolve the settings path after a native dialog attempt and request policy.
   --
   --  Save dialogs append Required_Extension when the selected path has no
   --  matching extension. Open dialogs leave the selected path unchanged.
   --
   --  @param Configured_Path Existing central settings file path.
   --  @param Request Native dialog request that produced Dialog_Result.
   --  @param Dialog_Result Native dialog result to apply.
   --  @return Selected dialog path when completed, otherwise Configured_Path.
   function Settings_Path_After_Dialog
     (Configured_Path : String;
      Request         : Native_File_Dialog_Request;
      Dialog_Result   : Native_File_Dialog_Result)
      return UString;

   --  Return whether a native dialog result selected a usable path.
   --
   --  @param Dialog_Result Native dialog result to inspect.
   --  @return True only when the dialog completed with a non-empty path.
   function Settings_Path_Selected
     (Dialog_Result : Native_File_Dialog_Result)
      return Boolean;

   --  Return the live-window smoke-test plan for the current environment.
   --
   --  @param Width Requested smoke window width in pixels.
   --  @param Height Requested smoke window height in pixels.
   --  @return Plan describing whether a live smoke can run and why.
   function Live_Window_Smoke_Plan
     (Width  : Natural := 1024;
      Height : Natural := 768)
      return Live_Smoke_Plan;

   --  Evaluate a live-window smoke plan without opening a native window.
   --
   --  This returns the execution contract a live harness must satisfy. It does
   --  not create windows in headless test runs.
   --
   --  @param Plan Live smoke plan to evaluate.
   --  @return Structured live smoke execution result.
   function Evaluate_Live_Window_Smoke
     (Plan : Live_Smoke_Plan)
      return Live_Smoke_Result;

   --  Execute a bounded live-window smoke test when Plan allows it.
   --
   --  This opens one native window for each startup window, polls input,
   --  renders the requested frame count, releases all windows, and returns a
   --  structured result. If Plan cannot run, it returns the skipped result.
   --
   --  @param Startup Startup result containing window models to smoke-test.
   --  @param Plan Live smoke plan to execute.
   --  @return Structured live smoke execution result.
   function Run_Live_Window_Smoke
     (Startup : Startup_Result;
      Plan    : Live_Smoke_Plan)
      return Live_Smoke_Result;

end Files.Application.Windows;
