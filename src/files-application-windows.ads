with Files.Preference_Types;
with Glfw.Windows.Drop.Paths;
with Files.Model;
with Files.Refresh;
with Files.Application.Window_Policy;
with Guikit.Layout;
with Guikit.Vulkan;
with Glfw;
with Glfw.Input.Mouse;

private with Ada.Containers.Vectors;
private with Ada.Exceptions;
private with Ada.Real_Time;
private with Ada.Strings.Unbounded;
private with A11ykit.Provider;
private with Files.Application.Accessibility;
private with Files.Commands;
private with Files.Drop_Events;
private with Files.Input_Actions;
private with Files.Overlays;
private with Files.Rendering;
private with Files.Rendering.Text;
private with Files.Application.Snapshot_Slots;
private with Files.Settings;
private with Files.Types;
private with Glfw.Input.Keys;
private with Glfw.Windows;
private with Guikit.Draw;
private with Guikit.Input;
private with Guikit.Input.Mouse_Buttons;

--  GLFW-backed desktop window session for resolved startup windows.
package Files.Application.Windows is
   Desktop_Error : exception;

   --  What this host offers a desktop run, found without opening a window.
   subtype Desktop_Capabilities is Files.Application.Window_Policy.Desktop_Capabilities;

   --  Create one GLFW window for each startup window and run until all close.
   --
   --  If GLFW cannot initialize or a native window cannot be created, this
   --  raises Desktop_Error after releasing any windows already created.
   --
   --  @param Startup Startup result containing window models to open.
   procedure Run
     (Startup : Startup_Result);

   --  Stop a closing window's helpers without waiting for filesystem I/O. A
   --  modal job is cancelled as the user's Cancel does, keeping its grace to
   --  undo a replace half done, and a paste's progress is recorded in the
   --  window's history before the paste is let go.
   --  @param Model Closing window whose transfer, operation and refresh sessions to release.
   --  @param Watch Closing window's native notification session to release.
   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh.Watch_Session);

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
      Pending_Mouse : Guikit.Input.Mouse_Buttons.Button_Event_Vectors.Vector;
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
      --  click "did nothing". See Guikit.Input.Mouse_Buttons.Left_Press_Debounce.
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

   --  The window-system callbacks below run from GLFW's C callbacks, so each
   --  ends in a handler that notes an exception (Note_Event_Loop) and returns
   --  rather than let it unwind into C. They do not extend
   --  Guikit.Input.Pending.Pending_Window: files coalesces typing, ties a
   --  key's own character to its press, and tracks drags and right-clicks,
   --  which that window's queue has no place for.
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

   --  A window keeps two view snapshots (see Files.Application.Snapshot_Slots).
   subtype Snapshot_Slot is Files.Application.Snapshot_Slots.Snapshot_Slot;
   use type Snapshot_Slot;

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

   --  What a window-layer overlay's commands are built from: the model (the
   --  palette's query and selection, the settings panel's state and draft),
   --  the window's live settings (their revision, Files.Model.Settings_Revision,
   --  which a theme change moves too -- the commands carry colour roles the
   --  frame's palette resolves when it is submitted), the overlay's region
   --  and line height, its focus and the pointer over it (-1 off the
   --  overlay, and always for the palette, which draws no hover). The
   --  commands are rebuilt only when this moves, or when the window adopts
   --  another window's settings (Share_Settings_From).
   type Overlay_Inputs is record
      Model_Revision    : Natural := 0;
      Settings_Revision : Natural := 0;
      Region            : Files.Overlays.Overlay_Region;
      Focused           : Boolean := False;
      Hover_X           : Integer := -1;
      Hover_Y           : Integer := -1;
   end record;

   --  Everything besides the snapshot that a frame is built from: its size
   --  and the pointer. A frame is rebuilt only when these or the snapshot
   --  change, compared as one record.
   type Frame_Inputs is record
      Width       : Natural := 0;
      Height      : Natural := 0;
      Line_Height : Positive := Guikit.Layout.Reference_Line_Height;
      Pointer     : Files.Rendering.Pointer_State := Files.Rendering.No_Pointer;
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
      Target   : Files.Preference_Types.Detail_Column := Files.Preference_Types.Modified_Column;
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
      Target   : Files.Preference_Types.Detail_Column := Files.Preference_Types.Modified_Column;
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
      Base     : Files.Types.String_Vectors.Vector;
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
      --  The main view's scroll offset, in pixels, that Origin_Y is a screen
      --  point for: each pass shifts the origin by the change since.
      Scroll_Pixels : Natural := 0;
   end record;

   type Runtime_Window is record
      Handle          : Window_Access;
      A11y_Key        : Files.Application.Accessibility.Window_Key := 0;
      --  This window's part of the screen reader's tree.
      Model           : Files.Model.Window_Model;
      Settings        : Files.Settings.Settings_Model;
      --  The model's settings revision (Files.Model.Settings_Revision) as of
      --  the last cross-window sync; a difference means this window changed
      --  its settings since (see Sync_Settings_Across_Windows).
      Synced_Settings_Revision : Natural := 0;
      Settings_Path   : Ada.Strings.Unbounded.Unbounded_String;
      Drag_Source_Index : Natural := 0;
      --  Where the left button last went down, in framebuffer pixels: a
      --  control is drawn pressed only where the press began.
      Press_X, Press_Y : Natural := 0;
      Scrollbar_Drag_Target : Files.Input_Actions.Scroll_Target := Files.Input_Actions.No_Scroll_Target;
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
      Deferred_Click         : Files.Input_Actions.Input_Action;
      --  The deferred click's item, found again by path at release: a
      --  refresh in between can move it to another row or remove it.
      Deferred_Click_Path    : Ada.Strings.Unbounded.Unbounded_String;
      Deferred_Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      --  Monotonic time of the last grid type-ahead keystroke; the event loop clears
      --  the pending prefix once this is older than Type_Ahead_Timeout so a fresh
      --  keystroke after a pause starts a new prefix.
      Type_Ahead_Input_At : Ada.Real_Time.Time := Never;
      --  The window's text: its fonts, a failed load's retry, its glyphs.
      Text            : Files.Rendering.Text.Window_Text;
      --  The size text is drawn at, in framebuffer pixels: the setting's
      --  size times Pixel_Ratio, the framebuffer's pixels per window pixel
      --  (2.0 on a Retina display), so text keeps its size on screen.
      Font_Pixel_Size : Positive := 16;
      Pixel_Ratio     : Float := 1.0;
      --  The window title last set.
      Shown_Title : Ada.Strings.Unbounded.Unbounded_String;
      Vulkan          : Guikit.Vulkan.Vulkan_Renderer;
      Shown           : Boolean := False;
      --  Frames Vulkan did not present (FILES_DIAGNOSTICS traces them).
      Fallback_Frames : Natural := 0;
      --  Frame command caching: when none of the rendering inputs change
      --  between two Render_Window calls, skip the expensive layout and
      --  Build_Frame_Commands rebuild and reuse the previously built data.
      Frame_Cache_Valid    : Boolean := False;
      --  Present-gate state: whether we have presented at least once, and the
      --  overlays of the last presented frame (kept when an overlay was built
      --  or dropped, the only times it can differ). A frame is re-presented only
      --  when its commands or an overlay's changed (opened, closed, typed in,
      --  hovered), or the text is not yet settled -- otherwise the identical
      --  frame is left on screen and the whole submit/present path is skipped.
      Presented_Once             : Boolean := False;
      Last_Palette               : Overlay_Commands;
      Last_Settings              : Overlay_Commands;
      --  Each overlay's commands while it is shown (Shown False otherwise),
      --  the inputs they were built from, and whether they were built since
      --  it was last hidden: an idle overlay is not rebuilt every loop pass.
      Palette_Overlay            : Overlay_Commands;
      Palette_Overlay_From       : Overlay_Inputs;
      Palette_Overlay_Built      : Boolean := False;
      Settings_Overlay           : Overlay_Commands;
      Settings_Overlay_From      : Overlay_Inputs;
      Settings_Overlay_Built     : Boolean := False;
      --  Frames still owed a present after the last visible change (grace window,
      --  see Present_Grace_Frames). Nonzero keeps us presenting every frame so
      --  interaction stays paced to the display; it decays to zero when idle and
      --  the present gate may then skip.
      Present_Grace              : Natural := 0;
      --  The window's view snapshots, current and drawn, and what keeps them
      --  current (Files.Application.Snapshot_Slots; Refresh_Snapshot refreshes them).
      View                 : Files.Application.Snapshot_Slots.View_Slots;
      Cached_Frame         : Files.Rendering.Frame_Commands;
      --  The Details rows' texts Cached_Frame was drawn with, kept for the
      --  next frame drawn from the same snapshot build (a pointer move).
      Row_Texts            : Files.Rendering.Row_Text_Cache;
      --  The pointer and size inputs Cached_Frame was built for. The time
      --  it shows is its snapshot's (View_Snapshot.Now).
      Cached_Inputs        : Frame_Inputs;
      --  What is shown when it is not Cached_Frame itself: Cached_Frame with
      --  the overlays merged in and, in a right-to-left layout, reflected.
      --  Valid while it was made from the frame and overlays shown now, in
      --  the direction Shown_Frame_Mirrored says (Present_Frame keeps it).
      Shown_Frame          : Files.Rendering.Frame_Commands;
      Shown_Frame_Valid    : Boolean := False;
      Shown_Frame_Mirrored : Boolean := False;
      Last_Glyph_Count : Natural := 0;
      --  Glyphs of the last frame no font drew (FILES_DIAGNOSTICS traces it).
      Last_Missing_Glyph_Count : Natural := 0;
      Last_Present_Status : Guikit.Vulkan.Vulkan_Status :=
        Guikit.Vulkan.Vulkan_Not_Initialized;
      Last_Watch_Poll : Ada.Real_Time.Time := Never;
      Watch : Files.Refresh.Watch_Session;
      --  How often the watch and the timed re-read may reload the folder.
      Watch_Pacing : Files.Refresh.Watch_Pacer;
   end record;

   --  The setting's text size in this window's framebuffer pixels.
   function Scaled_Font_Size (Runtime : Runtime_Window) return Positive is
     (Files.Application.Window_Policy.Scaled_Font_Size (Runtime.Settings.Font_Pixel_Size, Runtime.Pixel_Ratio));

   package Runtime_Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Runtime_Window);

   --  The GLFW window reference of a desktop window.
   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference;

   --  Bring the window's current snapshot up to date with its model.
   --
   --  @param Runtime Window whose current snapshot is refreshed.
   procedure Refresh_Snapshot (Runtime : in out Runtime_Window);

   --  The snapshot slot to hit-test pointer input against.
   --
   --  @param Runtime Window asked about.
   --  @return The drawn slot, or the refreshed current one before any frame.
   function Hit_Slot (Runtime : in out Runtime_Window) return Snapshot_Slot;

   --  Write the system-clipboard request the model recorded, if any.
   --
   --  @param Runtime Window whose request is written and cleared.
   procedure Flush_System_Clipboard (Runtime : in out Runtime_Window);

   --  Reveal the selection when a step since the last reveal set it by name.
   --
   --  @param Runtime Window whose selection may be scrolled into view.
   procedure Reveal_Pending_Selection (Runtime : in out Runtime_Window);

   --  Drain one window's queued key presses and typed text.
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window);

   --  Dispatch a click's input action to a window.
   procedure Dispatch_Click_Action
     (Runtime  : in out Runtime_Window;
      Action   : Files.Input_Actions.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set);

   --  Where a pointer event lands in a window's frame, and what to hit-test
   --  it against: framebuffer coordinates, the frame's size and line
   --  height, and the snapshot slot drawn there (Hit_Slot). Inside is False
   --  for a cursor on or beyond the window's edge, or an empty frame: such a
   --  position names no pixel (Scale_Coordinate returns the framebuffer
   --  extent there), and the rest is then not set.
   type Hit_Position is record
      Inside      : Boolean := False;
      X           : Natural := 0;
      Y           : Natural := 0;
      Width       : Natural := 0;
      Height      : Natural := 0;
      Line_Height : Positive := Guikit.Layout.Reference_Line_Height;
      Slot        : Snapshot_Slot := Snapshot_Slot'First;
   end record;

   --  Where a cursor position lands in a window's frame.
   --
   --  @param Runtime Window hit; its snapshot is refreshed before any frame.
   --  @param Window_W Window width in screen coordinates.
   --  @param Window_H Window height in screen coordinates.
   --  @param Frame_W Framebuffer width in pixels.
   --  @param Frame_H Framebuffer height in pixels.
   --  @param Cursor_X Cursor X in window coordinates.
   --  @param Cursor_Y Cursor Y in window coordinates.
   --  @return The position and what to hit-test it against.
   function Hit_Position_At
     (Runtime  : in out Runtime_Window;
      Window_W : Glfw.Size;
      Window_H : Glfw.Size;
      Frame_W  : Glfw.Size;
      Frame_H  : Glfw.Size;
      Cursor_X : Glfw.Input.Mouse.Coordinate;
      Cursor_Y : Glfw.Input.Mouse.Coordinate)
      return Hit_Position;

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
      return Files.Input_Actions.Input_Action;

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
