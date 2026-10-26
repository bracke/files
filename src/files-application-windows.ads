with Files.Model;
with Files.Refresh_Jobs;
with Files.Controller;
with Guikit.Vulkan;
with Glfw;
with Glfw.Input.Mouse;

private with Ada.Containers.Vectors;
private with Ada.Real_Time;
private with Ada.Strings.Unbounded;
private with A11ykit.Provider;
private with Files.Accessibility;
private with Files.Commands;
private with Files.Drop_Events;
private with Files.Events;
private with Files.Rendering;
private with Files.Settings;
private with Files.Types;
private with Glfw.Input.Keys;
private with Glfw.Windows;
private with Guikit.Draw;
private with Guikit.Input;

--  GLFW-backed desktop window session for resolved startup windows.
package Files.Application.Windows is
   Desktop_Error : exception;

   type Desktop_Capabilities is record
      Display_Available       : Boolean := False;
      Vulkan_Available        : Boolean := False;
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
      Event_Source_Backend            : Boolean := True;
      Queued_Drop_Imports             : Boolean := True;
      Requires_OS_Event_Source        : Boolean := False;
      Uses_Shell                      : Boolean := False;
      Max_Paths                       : Positive := 256;
      Binding_Unit                    : UString;
   end record;

   --  Create one GLFW window for each startup window and run until all close.
   --
   --  If GLFW cannot initialize or a native window cannot be created, this
   --  raises Desktop_Error after releasing any windows already created.
   --
   --  @param Startup Startup result containing window models to open.
   procedure Run
     (Startup : Startup_Result);

   --  Stop a closing window's helpers without waiting for filesystem I/O.
   --  @param Model Closing window whose transfer, operation and refresh sessions to release.
   --  @param Watch Closing window's native notification session to release.
   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh_Jobs.Watch_Session);

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

   --  Convert a scrollbar thumb position into its logical scroll offset.
   --
   --  Thumb_Top is relative to the beginning of the track. Positions beyond
   --  the usable thumb travel are clamped, so the bottom of the track maps to
   --  Maximum exactly even when the content's final page is partial.
   --
   --  @param Thumb_Top Relative top of the dragged thumb.
   --  @param Track_Length Total scrollbar track length.
   --  @param Thumb_Length Length of the draggable thumb.
   --  @param Maximum Largest valid logical scroll offset.
   --  @return Proportional logical offset in the range 0 .. Maximum.
   function Scrollbar_Drag_Offset
     (Thumb_Top    : Natural;
      Track_Length : Natural;
      Thumb_Length : Natural;
      Maximum      : Natural)
      return Natural;

   --  Return whether raw GLFW cursor coordinates name a pixel inside a window.
   --  Test this before scaling: Scale_Coordinate clamps negative values to zero,
   --  which intentionally loses the distinction between outside-left/top and
   --  the first pixel.
   --
   --  @param X Raw horizontal cursor coordinate.
   --  @param Y Raw vertical cursor coordinate.
   --  @param Width Window width in screen coordinates.
   --  @param Height Window height in screen coordinates.
   --  @return True when the coordinate lies inside the half-open window bounds.
   function Cursor_Is_Inside_Window
     (X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate;
      Width  : Glfw.Size;
      Height : Glfw.Size)
      return Boolean;

private

   --  The window session's internals, shared with the smoke harness
   --  (Files.Application.Windows.Smoke), which drives real windows through
   --  the same input and render steps the event loop takes.

   --  The keys the window tracks for presses, auto-repeat and shortcuts.
   type Tracked_Key is
     (Tracked_Key_1,
      Tracked_Key_2,
      Tracked_Key_3,
      Tracked_Key_4,
      Tracked_A,
      Tracked_B,
      Tracked_C,
      Tracked_D,
      Tracked_F,
      Tracked_I,
      Tracked_L,
      Tracked_N,
      Tracked_P,
      Tracked_R,
      Tracked_S,
      Tracked_V,
      Tracked_X,
      Tracked_Z,
      Tracked_Comma,
      Tracked_Backspace,
      Tracked_Delete,
      Tracked_F2,
      Tracked_F5,
      Tracked_Escape,
      Tracked_Enter,
      Tracked_Numpad_Enter,
      Tracked_Left,
      Tracked_Right,
      Tracked_Up,
      Tracked_Down,
      Tracked_Home,
      Tracked_End,
      Tracked_Page_Up,
      Tracked_Page_Down,
      Tracked_Equal,
      Tracked_Minus,
      Tracked_Right_Bracket,
      Tracked_Slash,
      Tracked_Numpad_Add,
      Tracked_Numpad_Subtract,
      Tracked_Zero,
      Tracked_Space,
      Tracked_Key_5, Tracked_Key_6, Tracked_Key_7, Tracked_Key_8, Tracked_Key_9,
      Tracked_E, Tracked_G, Tracked_H, Tracked_J, Tracked_K, Tracked_M, Tracked_O,
      Tracked_Q, Tracked_T, Tracked_U, Tracked_W, Tracked_Y,
      Tracked_F1, Tracked_F3, Tracked_F4, Tracked_F6, Tracked_F7, Tracked_F8, Tracked_F9,
      Tracked_F10, Tracked_F11, Tracked_F12,
      Tracked_Tab, Tracked_Insert, Tracked_Menu);

   --  Keyboard input in arrival order. Draining key presses and typed text as
   --  separate batches ran them out of order: text typed before Enter in a
   --  fast burst reached the field after Enter had committed it, and a
   --  shortcut's own character could swallow text typed around it.
   type Input_Event_Kind is (Key_Press_Event, Text_Event);

   type Input_Event is record
      Kind      : Input_Event_Kind := Text_Event;
      Key       : Tracked_Key := Tracked_Escape;
      --  The physical key, polled for auto-repeat while it is held.
      Physical  : Glfw.Input.Keys.Key := Glfw.Input.Keys.Unknown;
      --  Modifiers held when the key went down, not when the queue drains.
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Text      : Ada.Strings.Unbounded.Unbounded_String;
      --  Text produced by the key press just before it (its own character),
      --  which a consumed shortcut discards.
      Parallel  : Boolean := False;
   end record;

   package Input_Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Input_Event);

   Max_Pending_Input_Events : constant := 256;

   type Desktop_Window is new Glfw.Windows.Window with record
      Pending_Input : Input_Event_Vectors.Vector;
      --  True between a tracked key press and the next callback, so that
      --  callback's character is known to be the press's own.
      Last_Was_Tracked_Press : Boolean := False;
      Pending_Scroll : Integer := 0;
      Pending_Scroll_Remainder : Long_Float := 0.0;
      Pending_Left_Clicks : Natural := 0;
      Pending_Left_Releases : Natural := 0;
      Pending_Right_Clicks : Natural := 0;
      Last_Mouse_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Last_Mouse_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Drag_Start_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Drag_Start_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Left_Mouse_Down : Boolean := False;
      Drag_Moved : Boolean := False;
      --  Time of the last accepted left-button press, for bounce rejection: a
      --  failing mouse switch (or an un-debounced compositor) can emit a spurious
      --  second press within a few ms of the real one, which double-fires the
      --  click -- for a toggle toolbar icon that cancels out and looks like the
      --  click "did nothing". See Left_Press_Debounce.
      Last_Left_Press_Time : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Drop_Source : Files.Drop_Events.Drop_Event_Source;
   end record;

   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character);

   overriding procedure Key_Changed
     (Object   : not null access Desktop_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers);

   overriding procedure Mouse_Scrolled
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Scroll_Offset;
      Y      : Glfw.Input.Mouse.Scroll_Offset);

   overriding procedure Mouse_Button_Changed
     (Object : not null access Desktop_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers);

   overriding procedure Mouse_Position_Changed
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate);

   type Window_Access is access all Desktop_Window;

   type Pressed_Key_Map is array (Tracked_Key) of Boolean;
   type Key_Time_Map    is array (Tracked_Key) of Ada.Real_Time.Time;
   type Physical_Key_Map is array (Tracked_Key) of Glfw.Input.Keys.Key;

   --  Input timers run on the monotonic clock: the wall clock can step back
   --  (NTP, VM resume), which would make every press look like a bounce or a
   --  double click and stall repeat and polling. Never is the "no event yet"
   --  stamp; a timer is due once Now >= Stamp + Span, which a Never stamp
   --  always is (subtracting Never instead would overflow the Time_Span).
   Never : constant Ada.Real_Time.Time := Ada.Real_Time.Time_First;

   --  The text line height for a font pixel size.
   function Cell_Height_For (Size : Positive) return Positive is
     (Positive'Max (1, Size * 5 / 4));

   --  A window keeps two view snapshots (see Runtime_Window.Snapshots).
   type Snapshot_Slot is range 1 .. 2;
   type Snapshot_Slot_Array is array (Snapshot_Slot) of Files.Rendering.View_Snapshot;
   type Slot_Listing_Array is array (Snapshot_Slot) of Natural;

   type Runtime_Window is record
      Handle          : Window_Access;
      A11y_Key        : Files.Accessibility.Window_Key := 0;
      --  This window's part of the screen reader's tree.
      Shown_Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      --  The accessibility nodes of the frame last shown, overlays included.
      Model           : Files.Model.Window_Model;
      Settings        : Files.Settings.Settings_Model;
      --  Settings as of the last cross-window sync; a difference means this
      --  window changed them since (see Sync_Settings_Across_Windows).
      Synced_Settings : Files.Settings.Settings_Model;
      Settings_Path   : Ada.Strings.Unbounded.Unbounded_String;
      Pressed_Keys    : Pressed_Key_Map := [others => False];
      Key_Pressed_At  : Key_Time_Map := [others => Never];
      Key_Last_Fired  : Key_Time_Map := [others => Never];
      --  The physical key held for each tracked key, which differs from the
      --  tracked key's own position when the layout moved its letter.
      Held_Physical   : Physical_Key_Map := [others => Glfw.Input.Keys.Unknown];
      Left_Mouse_Down : Boolean := False;
      Drag_Source_Index : Natural := 0;
      Scrollbar_Drag_Target : Files.Events.Scroll_Target := Files.Events.Scroll_Auto;
      Scrollbar_Drag_Anchor : Integer := 0;
      --  Details-header column-resize drag state, owned by the shell exactly like
      --  the scrollbar drag above. Active gates a live resize; Target names the
      --  column, Origin_X the separator edge, and Origin_Width the column's width
      --  when the drag began, so each move sets width = origin +/- pointer delta.
      --  Changed records that a move resized the column in memory, so the drag's
      --  end writes the settings once.
      Column_Resize_Active  : Boolean := False;
      Column_Resize_Changed : Boolean := False;
      Column_Resize_Target  : Files.Types.Detail_Column := Files.Types.Modified_Column;
      Column_Resize_Origin_X : Integer := 0;
      Column_Resize_Origin_W : Natural := 0;
      --  Details-header column-reorder drag state, owned by the shell like the
      --  resize drag. Active gates a live reorder; Target names the dragged
      --  column, Origin_X the press x, Started records whether the pointer has
      --  crossed the drag threshold (distinguishing a reorder from a sort
      --  click), and Sort_Command the sort to apply on a click without a drag.
      Column_Reorder_Active  : Boolean := False;
      Column_Reorder_Target  : Files.Types.Detail_Column := Files.Types.Modified_Column;
      Column_Reorder_Origin_X : Integer := 0;
      Column_Reorder_Started  : Boolean := False;
      Column_Reorder_Sort    : Files.Commands.Command_Id := Files.Commands.No_Command;
      --  Rubber-band (marquee) selection drag state, owned by the shell like the
      --  drags above. Active gates the gesture; Origin_X/Y is the press point;
      --  Moved records whether the pointer crossed the drag threshold (below it a
      --  press is a plain empty-space click that leaves the selection untouched);
      --  Additive unions with Base (the selection captured at press) for a
      --  Ctrl/Shift marquee; Rect_* is the live rectangle surfaced to the
      --  renderer while Active.
      Marquee_Active   : Boolean := False;
      Marquee_Origin_X : Integer := 0;
      Marquee_Origin_Y : Integer := 0;
      Marquee_Moved    : Boolean := False;
      Marquee_Additive : Boolean := False;
      Marquee_Base     : Files.Rendering.Visible_Index_Vectors.Vector;
      Marquee_Rect_X   : Natural := 0;
      Marquee_Rect_Y   : Natural := 0;
      Marquee_Rect_W   : Natural := 0;
      Marquee_Rect_H   : Natural := 0;
      Last_Click_Item : Natural := 0;
      Last_Click_Path : Ada.Strings.Unbounded.Unbounded_String;
      Last_Click_Time : Ada.Real_Time.Time := Never;
      --  A press on part of a selection, held back until its release shows
      --  whether it began a drag of the whole selection.
      Deferred_Click_Pending : Boolean := False;
      Deferred_Click         : Files.Events.Input_Action;
      Deferred_Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      --  Monotonic time of the last grid type-ahead keystroke; the event loop clears
      --  the pending prefix once this is older than Type_Ahead_Timeout so a fresh
      --  keystroke after a pause starts a new prefix.
      Type_Ahead_Input_At : Ada.Real_Time.Time := Never;
      Text            : Files.Rendering.Text_Renderer;
      Text_Ready      : Boolean := False;
      Font_Pixel_Size : Positive := 16;
      --  The window title last set.
      Shown_Title : Ada.Strings.Unbounded.Unbounded_String;
      --  The font pixel size text initialization last failed at, or 0. It is
      --  not retried at that size every frame (nor does the failure keep the
      --  window presenting); a size change tries again.
      Text_Failed_Size : Natural := 0;
      --  When it last failed; it is tried again after Text_Retry_Interval.
      Text_Failed_At   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      --  The text Text_Glyphs were built from, while Glyph_Text_Valid: equal
      --  text commands reuse the glyphs (the fonts and atlas stay loaded).
      Glyph_Text         : Guikit.Draw.Text_Command_Vectors.Vector;
      Glyph_Overlay_Text : Guikit.Draw.Text_Command_Vectors.Vector;
      Glyph_Text_Valid   : Boolean := False;
      Text_Glyphs     : Files.Rendering.Text_Render_Result;
      Vulkan          : Guikit.Vulkan.Vulkan_Renderer;
      Shown           : Boolean := False;
      Fallback_Frames : Natural := 0;
      --  Frame command caching: when none of the rendering inputs change
      --  between two Render_Window calls, skip the expensive layout and
      --  Build_Frame_Commands rebuild and reuse the previously built data.
      Frame_Cache_Valid    : Boolean := False;
      --  Present-gate state: whether we have presented at least once, and the
      --  overlay open-states of the last presented frame. A frame is re-presented
      --  only when its commands changed, an overlay is (or just was) open, or the
      --  text is not yet settled -- otherwise the identical frame is left on
      --  screen and the whole submit/present path is skipped.
      Presented_Once             : Boolean := False;
      Last_Present_Palette_Open  : Boolean := False;
      Last_Present_Settings_Open : Boolean := False;
      --  Frames still owed a present after the last visible change (grace window,
      --  see Present_Grace_Frames). Nonzero keeps us presenting every frame so
      --  interaction stays paced to the display; it decays to zero when idle and
      --  the present gate may then skip.
      Present_Grace              : Natural := 0;
      --  The window's view snapshots. Snapshots (Current_Slot) is the model as
      --  it is now, kept current by Refresh_Snapshot for the render and for
      --  every input handler that lays the view out; Snapshots (Drawn_Slot) is
      --  the one Cached_Frame was built from, what is on screen, which clicks
      --  are hit-tested against. They are one slot until the model changes
      --  between frames: Refresh_Snapshot then builds into the other slot, so
      --  the drawn snapshot survives until the next render draws the new one.
      --  Snapshot_Valid is False until the first build and after any change
      --  the keys below do not see (a replaced model).
      Snapshots       : Snapshot_Slot_Array;
      --  The model's listing revision each slot was built at: a click on a
      --  drawn item whose listing has changed since is matched by name.
      Slot_Listings   : Slot_Listing_Array := [others => 0];
      Current_Slot    : Snapshot_Slot := 1;
      Drawn_Slot      : Snapshot_Slot := 1;
      Snapshot_Valid  : Boolean := False;
      --  Wall-clock minute the current snapshot was built in: relative times
      --  and the Today / This week bands are computed from the clock.
      Snapshot_Minute : Natural := 0;
      --  Model revision the current snapshot was built at. It is reused only
      --  while the model's revision still matches, so a background poll (file
      --  watch, folder sizes) that changed nothing forces no O(items) rebuild.
      Cached_Model_Revision : Natural := 0;
      --  Snapshot-relevant settings (theme, columns, visibility, favorites,
      --  labels) the current snapshot was built with. With the model revision
      --  these are the whole of Build_Snapshot's inputs, so the snapshot is
      --  reused only while both still match -- no explicit invalidation.
      Cached_Settings_Key  : Files.Settings.Snapshot_Settings_Key;
      Cached_Frame         : Files.Rendering.Frame_Commands;
      Cached_Frame_W       : Natural := 0;
      Cached_Frame_H       : Natural := 0;
      Cached_Line_Height   : Positive := 20;
      Cached_Hover_X       : Natural := 0;
      Cached_Hover_Y       : Natural := 0;
      Cached_Has_Hover     : Boolean := False;
      Cached_Has_Press     : Boolean := False;
      Cached_Drag_Item     : Natural := 0;
      Cached_Has_Drag      : Boolean := False;
      Cached_Marquee_Active : Boolean := False;
      Cached_Marquee_X     : Natural := 0;
      Cached_Marquee_Y     : Natural := 0;
      Cached_Marquee_W     : Natural := 0;
      Cached_Marquee_H     : Natural := 0;
      --  Wall-clock minute the cached frame was built in. Relative times
      --  ("now", "Today 23:50") and the Today / This week group bands are
      --  computed from the clock, which no other key covers.
      Cached_Minute        : Natural := 0;
      Last_Glyph_Count : Natural := 0;
      Last_Missing_Glyph_Count : Natural := 0;
      Last_Present_Status : Guikit.Vulkan.Vulkan_Status :=
        Guikit.Vulkan.Vulkan_Not_Initialized;
      Last_Watch_Poll : Ada.Real_Time.Time := Never;
      Watch : Files.Refresh_Jobs.Watch_Session;
   end record;

   package Runtime_Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Runtime_Window);

   --  The value of environment variable Name, or "" when unset.
   function Safe_Environment_Value (Name : String) return String;

   --  The GLFW window reference of a desktop window.
   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference;

   --  The GLFW key of a tracked key.
   function To_Glfw_Key
     (Key : Tracked_Key)
      return Glfw.Input.Keys.Key;

   --  Drain one window's queued key presses and typed text.
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window);

   --  Handle_Keyboard for every window.
   procedure Handle_All_Keyboard
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Import the files dropped on every window.
   procedure Handle_All_Drop_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Poll every window's watched directory for changes.
   procedure Handle_All_File_Watch_Poll
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Apply every window's pending scroll.
   procedure Handle_All_Scroll_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Dispatch a click's input action to a window.
   procedure Dispatch_Click_Action
     (Runtime  : in out Runtime_Window;
      Action   : Files.Events.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set);

   --  The input action a click at a cursor position makes.
   function Current_Click_Action
     (Runtime   : in out Runtime_Window;
      Window_W  : Glfw.Size;
      Window_H  : Glfw.Size;
      Frame_W   : Glfw.Size;
      Frame_H   : Glfw.Size;
      Cursor_X  : Glfw.Input.Mouse.Coordinate;
      Cursor_Y  : Glfw.Input.Mouse.Coordinate;
      Modifiers : Guikit.Input.Modifier_Set)
      return Files.Events.Input_Action;

   --  Carry out a screen reader's request on a window.
   procedure Perform_Accessibility_Request
     (Runtime : in out Runtime_Window;
      Item    : A11ykit.Provider.Request);

   --  Apply one window's pending mouse input.
   procedure Handle_Mouse
     (Runtime : in out Runtime_Window);

   --  Handle_Mouse for every window.
   procedure Handle_All_Mouse
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Release every window and its resources.
   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector);

   --  Open a native window for a startup window and append it.
   procedure Append_Runtime_Window
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Startup_Window  : Files.Application.Startup_Window;
      Settings        : Files.Settings.Settings_Model;
      Settings_Path   : Ada.Strings.Unbounded.Unbounded_String;
      Width           : Natural;
      Height          : Natural);

   --  Render one window's frame.
   procedure Render_Window
     (Runtime : in out Runtime_Window);

   --  Whether any window has rendered a frame.
   function Any_Runtime_Frame_Rendered
     (Runtime_Windows : Runtime_Window_Vectors.Vector)
      return Boolean;

end Files.Application.Windows;
