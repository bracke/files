with Glfw.Windows.Drop.Paths;
with Files.Model;
with Files.Refresh_Jobs;
with Guikit.Layout;
with Guikit.Vulkan;
with Glfw;
with Glfw.Input.Mouse;

private with Ada.Containers.Vectors;
private with Ada.Exceptions;
private with Ada.Real_Time;
private with Ada.Strings.Unbounded;
private with A11ykit.Provider;
private with Files.Accessibility;
private with Files.Commands;
private with Files.Drop_Events;
private with Files.Events;
private with Files.Mouse_Buttons;
private with Files.Rendering;
private with Files.Snapshot_Slots;
private with Files.Settings;
private with Files.Types;
private with Files.Window_Policy;
private with Glfw.Input.Keys;
private with Glfw.Windows;
private with Guikit.Draw;
private with Guikit.Input;

--  GLFW-backed desktop window session for resolved startup windows.
package Files.Application.Windows is
   Desktop_Error : exception;

   --  What this host offers a desktop run, found without opening a window.
   type Desktop_Capabilities is record
      Display_Available       : Boolean := False;
      Vulkan_Available        : Boolean := False;
      Live_Window_Smoke_Ready : Boolean := False;
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

   --  The capabilities a host with this display and this Vulkan has: a live
   --  window smoke needs both.
   --
   --  @param Display Whether a window can be shown.
   --  @param Vulkan Whether Vulkan is usable.
   --  @return The capability flags.
   function Capabilities_Of (Display, Vulkan : Boolean) return Desktop_Capabilities is
     (Display_Available => Display, Vulkan_Available => Vulkan, Live_Window_Smoke_Ready => Display and then Vulkan);

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

   --  Keyboard input in arrival order. Draining key presses and typed text as
   --  separate batches ran them out of order: text typed before Enter in a
   --  fast burst reached the field after Enter had committed it, and a
   --  shortcut's own character could swallow text typed around it.
   type Input_Event_Kind is (Key_Press_Event, Text_Event);

   type Input_Event is record
      Kind      : Input_Event_Kind := Text_Event;
      Key       : Guikit.Input.Key_Code := Guikit.Input.Key_Escape;
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

   type Desktop_Window is new Glfw.Windows.Window and Glfw.Windows.Drop.Paths.Receiver with record
      Pending_Input : Input_Event_Vectors.Vector;
      --  True between a tracked key press and the next callback, so that
      --  callback's character is known to be the press's own.
      Last_Was_Tracked_Press : Boolean := False;
      --  True between a suppressed repeat and the next callback: the repeat's
      --  character (a held Space's spaces) is not typing either.
      Drop_Next_Character : Boolean := False;
      Pending_Scroll : Integer := 0;
      Pending_Scroll_Remainder : Long_Float := 0.0;
      --  Mouse button changes in arrival order, each with where it happened
      --  and the modifiers held then; Handle_Mouse drains them in order.
      Pending_Mouse : Files.Mouse_Buttons.Button_Event_Vectors.Vector;
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
      --  click "did nothing". See Files.Mouse_Buttons.Left_Press_Debounce.
      Last_Left_Press_Time : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Drop_Source : Files.Drop_Events.Drop_Event_Source;
   end record;

   --  Paths dropped on the window, queued for the loop to import.
   overriding procedure Receive
     (Into    : in out Desktop_Window;
      Dropped : Glfw.Windows.Drop.Paths.Path_Vectors.Vector);

   overriding procedure Failed
     (Into       : in out Desktop_Window;
      Occurrence : Ada.Exceptions.Exception_Occurrence);

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

   --  Input timers run on the monotonic clock: the wall clock can step back
   --  (NTP, VM resume), which would make every press look like a bounce or a
   --  double click and stall repeat and polling. Never is the "no event yet"
   --  stamp; a timer is due once Now >= Stamp + Span, which a Never stamp
   --  always is (subtracting Never instead would overflow the Time_Span).
   Never : constant Ada.Real_Time.Time := Ada.Real_Time.Time_First;

   --  The text line height for a font pixel size.
   function Cell_Height_For (Size : Positive) return Positive is
     (Positive'Max (1, Size * 5 / 4));

   --  A window keeps two view snapshots (see Files.Snapshot_Slots).
   subtype Snapshot_Slot is Files.Snapshot_Slots.Snapshot_Slot;
   use type Snapshot_Slot;

   --  Everything besides the snapshot that a frame is built from: its size
   --  and the pointer. A frame is rebuilt only when these (or the snapshot,
   --  or the minute) change, compared as one record.
   --  One window-layer overlay's draw commands (command palette or settings
   --  panel), as merged over the cached frame. Kept from the last present,
   --  an unchanged overlay is not presented again.
   type Overlay_Commands is record
      Shown         : Boolean := False;
      Rectangles    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
   end record;

   type Frame_Inputs is record
      Width          : Natural := 0;
      Height         : Natural := 0;
      Line_Height    : Positive := Guikit.Layout.Reference_Line_Height;
      Hover_X        : Natural := 0;
      Hover_Y        : Natural := 0;
      Has_Hover      : Boolean := False;
      Has_Press      : Boolean := False;
      Drag_Item      : Natural := 0;
      Has_Drag       : Boolean := False;
      Marquee_Active : Boolean := False;
      Marquee_X      : Natural := 0;
      Marquee_Y      : Natural := 0;
      Marquee_W      : Natural := 0;
      Marquee_H      : Natural := 0;
   end record;

   --  Details-header column-resize drag state, owned by the shell exactly like
   --  the scrollbar drag. Active gates a live resize; Target names the column,
   --  Origin_X the separator edge, and Origin_W the column's width when the
   --  drag began, so each move sets width = origin +/- pointer delta. Changed
   --  records that a move resized the column in memory, so the drag's end
   --  writes the settings once.
   type Column_Resize_Drag is record
      Active   : Boolean := False;
      Changed  : Boolean := False;
      Target   : Files.Types.Detail_Column := Files.Types.Modified_Column;
      Origin_X : Integer := 0;
      Origin_W : Natural := 0;
   end record;

   --  Details-header column-reorder drag state, owned by the shell like the
   --  resize drag. Active gates a live reorder; Target names the dragged
   --  column, Origin_X the press x, Started records whether the pointer has
   --  crossed the drag threshold (distinguishing a reorder from a sort click),
   --  and Sort the sort to apply on a click without a drag.
   type Column_Reorder_Drag is record
      Active   : Boolean := False;
      Target   : Files.Types.Detail_Column := Files.Types.Modified_Column;
      Origin_X : Integer := 0;
      Started  : Boolean := False;
      Sort     : Files.Commands.Command_Id := Files.Commands.No_Command;
   end record;

   --  Rubber-band (marquee) selection drag state, owned by the shell like the
   --  drags above. Active gates the gesture; Origin_X/Y is the press point;
   --  Moved records whether the pointer crossed the drag threshold (below it a
   --  press is a plain empty-space click that leaves the selection untouched);
   --  Additive unions with Base (the selection captured at press) for a
   --  Ctrl/Shift marquee; Rect_* is the live rectangle surfaced to the
   --  renderer while Active.
   type Marquee_Drag_State is record
      Active   : Boolean := False;
      Origin_X : Integer := 0;
      Origin_Y : Integer := 0;
      Moved    : Boolean := False;
      Additive : Boolean := False;
      Base     : Files.Rendering.Visible_Index_Vectors.Vector;
      Rect_X   : Natural := 0;
      Rect_Y   : Natural := 0;
      Rect_W   : Natural := 0;
      Rect_H   : Natural := 0;
      --  Where the last pass found the cursor and the scroll, and whether it
      --  auto-scrolled: with neither moved and no scroll under way, the band
      --  and its selection are what they were, and the pass does nothing.
      Last_X        : Integer := Integer'First;
      Last_Y        : Integer := Integer'First;
      Last_Scroll   : Natural := 0;
      Auto_Scrolled : Boolean := False;
   end record;

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
      Left_Mouse_Down : Boolean := False;
      Drag_Source_Index : Natural := 0;
      Scrollbar_Drag_Target : Files.Events.Scroll_Target := Files.Events.Scroll_Auto;
      Scrollbar_Drag_Anchor : Integer := 0;
      --  The three drags the shell owns besides the scrollbar's.
      Column_Resize   : Column_Resize_Drag;
      --  A wheel zoom is applied at once and saved once the wheel has been
      --  still for Zoom_Save_Delay (or the window closes): one durable write
      --  per gesture, not one per wheel step.
      Zoom_Unsaved    : Boolean := False;
      Zoom_At         : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Column_Reorder  : Column_Reorder_Drag;
      Marquee         : Marquee_Drag_State;
      Last_Click_Item : Natural := 0;
      Last_Click_Path : Ada.Strings.Unbounded.Unbounded_String;
      Last_Click_Time : Ada.Real_Time.Time := Never;
      --  A press on part of a selection, held back until its release shows
      --  whether it began a drag of the whole selection.
      Deferred_Click_Pending : Boolean := False;
      Deferred_Click         : Files.Events.Input_Action;
      --  The deferred click's item, found again by path at release: a
      --  refresh in between can move it to another row or remove it.
      Deferred_Click_Path    : Ada.Strings.Unbounded.Unbounded_String;
      Deferred_Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      --  Monotonic time of the last grid type-ahead keystroke; the event loop clears
      --  the pending prefix once this is older than Type_Ahead_Timeout so a fresh
      --  keystroke after a pause starts a new prefix.
      Type_Ahead_Input_At : Ada.Real_Time.Time := Never;
      Text            : Files.Rendering.Text_Renderer;
      Text_Ready      : Boolean := False;
      --  The size text is drawn at, in framebuffer pixels: the setting's
      --  size times Pixel_Ratio, the framebuffer's pixels per window pixel
      --  (2.0 on a Retina display), so text keeps its size on screen.
      Font_Pixel_Size : Positive := 16;
      Pixel_Ratio     : Float := 1.0;
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
      --  overlays of the last presented frame. A frame is re-presented only
      --  when its commands or an overlay's changed (opened, closed, typed in,
      --  hovered), or the text is not yet settled -- otherwise the identical
      --  frame is left on screen and the whole submit/present path is skipped.
      Presented_Once             : Boolean := False;
      Last_Palette               : Overlay_Commands;
      Last_Settings              : Overlay_Commands;
      --  Frames still owed a present after the last visible change (grace window,
      --  see Present_Grace_Frames). Nonzero keeps us presenting every frame so
      --  interaction stays paced to the display; it decays to zero when idle and
      --  the present gate may then skip.
      Present_Grace              : Natural := 0;
      --  The window's view snapshots, current and drawn, and what keeps them
      --  current (Files.Snapshot_Slots; Refresh_Snapshot refreshes them).
      View                 : Files.Snapshot_Slots.View_Slots;
      Cached_Frame         : Files.Rendering.Frame_Commands;
      --  The pointer and size inputs Cached_Frame was built for.
      Cached_Inputs        : Frame_Inputs;
      --  Wall-clock minute the cached frame was built in. Relative times
      --  ("now", "Today 23:50") and the Today / This week group bands are
      --  computed from the clock, which no other key covers.
      Cached_Minute        : Natural := 0;
      Last_Glyph_Count : Natural := 0;
      Last_Missing_Glyph_Count : Natural := 0;
      Last_Present_Status : Guikit.Vulkan.Vulkan_Status :=
        Guikit.Vulkan.Vulkan_Not_Initialized;
      Last_Watch_Poll : Ada.Real_Time.Time := Never;
      --  The model revision and transfer state Update_Folder_Size last ran
      --  for: the loop wakes about 60 times a second, and the selection's
      --  targets change only with the model.
      Folder_Size_Rows      : Natural := Natural'Last;
      Folder_Size_Selection : Natural := Natural'Last;
      Folder_Size_Busy     : Boolean := False;
      Watch : Files.Refresh_Jobs.Watch_Session;
      --  How often the watch and the timed re-read may reload the folder.
      Watch_Pacing : Files.Refresh_Jobs.Watch_Pacer;
   end record;

   --  The setting's text size in this window's framebuffer pixels.
   function Scaled_Font_Size (Runtime : Runtime_Window) return Positive is
     (Files.Window_Policy.Scaled_Font_Size (Runtime.Settings.Font_Pixel_Size, Runtime.Pixel_Ratio));

   package Runtime_Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Runtime_Window);

   --  The GLFW window reference of a desktop window.
   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference;

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

   --  What the event loop carries from one pass to the next.
   type Event_Loop_State is record
      Recovery_Reported : Boolean := False;
      --  When the recovery report is next looked for. An addition, not
      --  Clock - Last: subtracting Time_First overflows, and that raised on
      --  every pass of the loop, which then never drew another frame.
      Next_Recovery_Check : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;

   --  One pass of the event loop after its wait: screen-reader requests,
   --  input, settings sharing, rendering, watching and folder sizes for every
   --  window. Run and the live smoke both drive the windows through this, so
   --  the smoke runs the loop the program runs. A failure is counted
   --  (Files.Diagnostics.Note_Event_Loop) and the pass skipped.
   --
   --  @param Runtime_Windows The open windows.
   --  @param State Carried from the previous pass.
   procedure Event_Loop_Pass
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      State           : in out Event_Loop_State);

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
