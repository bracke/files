with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;

with Glfw.Input;
with Glfw.Input.Keys;
with Glfw.Windows;
with Glfw.Windows.Drop;
with Glfw.Windows.Hints;
with Glfw.Windows.Icon;
with Glfw.Windows.Vulkan;

with Files.Accessibility;
with Files.Commands;
with Files.Drop_Events;
with Files.Shared_Bytes;
with Files.Events;
with Files.File_System;
with Files.Folder_Size;
with Files.Folder_Tree;
with Files.Interaction;
with Files.Job_Scavenger;
with Files.Operations;
with Files.Quick_Look;
with Guikit.Draw;
with Guikit.Layout;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Guikit.Utf8;
with Files.Types;

package body Files.Application.Windows is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Glfw.Input.Button_State;
   use type Glfw.Input.Mouse.Button;
   use type Glfw.Input.Mouse.Coordinate;
   use type Glfw.Size;
   use type Files.Events.Input_Action_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Detail_Column;
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Files.Rendering.View_Snapshot;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.Unsigned_32;
   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;

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
      Text      : Unbounded_String;
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
      Last_Left_Press_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
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

   Max_Drop_Paths : constant Positive := 256;

   type C_Path_Array is array (Positive range 1 .. Max_Drop_Paths) of Interfaces.C.Strings.chars_ptr;
   pragma Convention (C, C_Path_Array);

   package C_Path_Array_Pointers is new System.Address_To_Access_Conversions (C_Path_Array);
   use type C_Path_Array_Pointers.Object_Pointer;

   type Drop_Window_Registration is record
      Raw_Window : System.Address := System.Null_Address;
      Target     : Window_Access := null;
   end record;

   package Drop_Window_Registration_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Drop_Window_Registration);

   Registered_Drop_Windows : Drop_Window_Registration_Vectors.Vector;

   procedure Raw_Drop_Callback
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Paths  : System.Address)
   with Convention => C;

   type Pressed_Key_Map is array (Tracked_Key) of Boolean;
   type Key_Time_Map    is array (Tracked_Key) of Ada.Calendar.Time;
   type Physical_Key_Map is array (Tracked_Key) of Glfw.Input.Keys.Key;

   Key_Epoch : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);

   Key_Repeat_Initial_Delay : constant Duration := 0.4;
   Key_Repeat_Interval      : constant Duration := 0.04;

   function Key_Repeats (Key : Tracked_Key) return Boolean is
     (Key in Tracked_Left | Tracked_Right | Tracked_Up | Tracked_Down
           | Tracked_Page_Up | Tracked_Page_Down
           | Tracked_Backspace | Tracked_Delete
           | Tracked_Equal | Tracked_Minus
           | Tracked_Right_Bracket | Tracked_Slash
           | Tracked_Numpad_Add | Tracked_Numpad_Subtract);

   function Cell_Height_For (Size : Positive) return Positive is
     (Positive'Max (1, Size * 5 / 4));
   --  The text cell width is the advance every layout measures labels with,
   --  taken from the same line height. Derived separately (Size * 3 / 4) it
   --  came out a pixel wider at some sizes, so labels sized to fit lost their
   --  last character and large fonts read "Klei", "Gro", "hom".
   function Cell_Width_For  (Size : Positive) return Positive is
     (Guikit.Layout.Caret_Advance_Width (Cell_Height_For (Size)));

   type Runtime_Window is record
      Handle          : Window_Access;
      Model           : Files.Model.Window_Model;
      Settings        : Files.Settings.Settings_Model;
      --  Settings as of the last cross-window sync; a difference means this
      --  window changed them since (see Sync_Settings_Across_Windows).
      Synced_Settings : Files.Settings.Settings_Model;
      Settings_Path   : Unbounded_String;
      Pressed_Keys    : Pressed_Key_Map := [others => False];
      Key_Pressed_At  : Key_Time_Map := [others => Key_Epoch];
      Key_Last_Fired  : Key_Time_Map := [others => Key_Epoch];
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
      Column_Resize_Active  : Boolean := False;
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
      Last_Click_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      --  Wall-clock of the last grid type-ahead keystroke; the event loop clears
      --  the pending prefix once this is older than Type_Ahead_Timeout so a fresh
      --  keystroke after a pause starts a new prefix.
      Type_Ahead_Input_At : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Text            : Files.Rendering.Text_Renderer;
      Text_Ready      : Boolean := False;
      Font_Pixel_Size : Positive := 16;
      Text_Font_Path  : Unbounded_String;
      Text_Content_Key : Unbounded_String;
      Text_Content_Font_Path : Unbounded_String;
      Text_Glyph_Key  : Unbounded_String;
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
      Cached_Snapshot      : Files.Rendering.View_Snapshot;
      --  Model revision the Cached_Snapshot was built at. The next render reuses
      --  the snapshot only when the model's current revision still matches, so a
      --  background poll (file watch, folder sizes) that changed nothing no
      --  longer forces the O(items) Build_Snapshot.
      Cached_Model_Revision : Natural := 0;
      --  Snapshot-relevant settings (theme, columns, visibility, favorites,
      --  labels) the Cached_Snapshot was built with. Together with the model
      --  revision these are the whole of Build_Snapshot's inputs, so the snapshot
      --  is reused only while both still match -- no explicit invalidation.
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
      --  Wall-clock minute the cached snapshot and frame were built in.
      --  Relative times ("now", "Today 23:50") and the Today / This week
      --  group bands are computed from the clock, which no other key covers.
      Cached_Minute        : Natural := 0;
      Last_Glyph_Count : Natural := 0;
      Last_Missing_Glyph_Count : Natural := 0;
      Last_Present_Status : Guikit.Vulkan.Vulkan_Status :=
        Guikit.Vulkan.Vulkan_Not_Initialized;
      Last_Watch_Poll : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Watch : Files.Refresh_Jobs.Watch_Session;
   end record;

   package Runtime_Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Runtime_Window);

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

   --  The text renderer is process-wide; these record what it was last
   --  initialized for. Windows zoom independently, so the pixel size is part
   --  of the key: a window may only build glyphs once it matches its own size.
   Process_Text_Font_Ready : Boolean := False;
   Process_Text_Font_Path  : Unbounded_String;
   Process_Text_Font_Size  : Natural := 0;
   File_Watch_Poll_Interval : constant Duration := 1.0;
   Type_Ahead_Timeout : constant Duration := 1.0;
   --  The event loop always waits this long: input, window refresh, and posted
   --  events wake it immediately, and this bounds how long a background file
   --  change (native watch / interval poll) or an animation frame waits. Present
   --  is skipped for unchanged frames, so a short wait keeps input responsive
   --  without the idle cost of actually re-rendering. (An earlier adaptive
   --  long-idle wait cut idle CPU only ~2% -> ~1% but let input lag up to a
   --  second, so it was dropped.)
   Event_Wait_Timeout : constant Duration := 0.016;

   --  How many frames to keep presenting after the last visible change before
   --  the present gate is allowed to skip. Presenting every frame keeps us on
   --  the compositor's frame clock, which is what keeps input paced at the
   --  display rate; once we stop presenting that pacing drops and the *next*
   --  interaction after an idle gap stalls, which feels like laggy keyboard and
   --  mouse. So we stay presenting through a short grace window (~0.4s at 60fps)
   --  after any change -- normal typing/mouse movement never lets it lapse, so
   --  interaction stays crisp -- and only skip presents once genuinely idle,
   --  where the idle-CPU saving actually matters.
   Present_Grace_Frames : constant := 24;

   --  A left press landing within this window of the previous accepted press is
   --  treated as a hardware/compositor bounce and dropped. It is far shorter than
   --  any deliberate click or double-click (the double-click threshold is 0.5s),
   --  so it never rejects a real one, but it absorbs the microsecond-apart phantom
   --  presses a failing switch produces.
   Left_Press_Debounce : constant Duration := 0.040;
   --  Write UTF-8 text to the system text clipboard. The GLFWwindow* argument is
   --  retained for the historic signature; modern GLFW ignores it.
   procedure Set_Raw_Clipboard_String
     (Window : System.Address;
      Text   : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "glfwSetClipboardString";

   procedure Free_Window is new Ada.Unchecked_Deallocation
     (Object => Desktop_Window,
      Name   => Window_Access);

   function Safe_Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   --  Persist the runtime settings to the central settings file. The reducer
   --  owns the actual serialization; this wrapper exists for the shell-only
   --  GLFW/timing paths (live font zoom, window-size save on shutdown).
   procedure Persist_Settings (Runtime : in out Runtime_Window) is
   begin
      Files.Interaction.Persist_Settings
        (Runtime.Settings, To_String (Runtime.Settings_Path));
   end Persist_Settings;

   --  Write any pending system-clipboard request the model recorded (for
   --  example from the Copy Path command) to the GLFW system clipboard, then
   --  clear it. A no-op when no request is pending.
   procedure Flush_System_Clipboard (Runtime : in out Runtime_Window);

   --  Consume the GPU/GLFW/timing follow-up an interaction asks the shell to
   --  perform. Everything touching Runtime_Window's GPU/cache/input state stays
   --  here; Files.Interaction performs the model/settings mutation itself.
   procedure Apply_Interaction_Result
     (Runtime : in out Runtime_Window;
      Result  : Files.Interaction.Interaction_Result) is
   begin
      if Result.Font_Size_Changed then
         Runtime.Font_Pixel_Size := Runtime.Settings.Font_Pixel_Size;
      end if;
      if Result.Needs_Glyph_Rebuild then
         Runtime.Text_Ready := False;
         Runtime.Text_Glyph_Key := Null_Unbounded_String;
      end if;
      Flush_System_Clipboard (Runtime);
   end Apply_Interaction_Result;

   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference is
   begin
      return Glfw.Windows.Window_Reference (Handle);
   end As_Window;

   procedure Flush_System_Clipboard (Runtime : in out Runtime_Window) is
   begin
      if Runtime.Handle = null
        or else not Files.Model.System_Clipboard_Request_Pending (Runtime.Model)
      then
         return;
      end if;

      declare
         Raw    : constant System.Address :=
           Glfw.Windows.Drop.Raw_Handle (As_Window (Runtime.Handle));
         C_Text : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String
             (Files.Model.System_Clipboard_Request_Text (Runtime.Model));
      begin
         if Raw /= System.Null_Address then
            Set_Raw_Clipboard_String (Raw, C_Text);
         end if;
         Interfaces.C.Strings.Free (C_Text);
      end;

      Files.Model.Clear_System_Clipboard_Request (Runtime.Model);
   end Flush_System_Clipboard;

   procedure Register_Drop_Window
     (Raw_Window : System.Address;
      Target     : Window_Access) is
   begin
      if Raw_Window = System.Null_Address or else Target = null then
         return;
      end if;

      for Index in Registered_Drop_Windows.First_Index .. Registered_Drop_Windows.Last_Index loop
         if Registered_Drop_Windows.Element (Index).Raw_Window = Raw_Window then
            Registered_Drop_Windows.Replace_Element
              (Index,
               Drop_Window_Registration'
                 (Raw_Window => Raw_Window,
                  Target     => Target));
            return;
         end if;
      end loop;

      Registered_Drop_Windows.Append
        (Drop_Window_Registration'
           (Raw_Window => Raw_Window,
            Target     => Target));
   end Register_Drop_Window;

   procedure Unregister_Drop_Window
     (Raw_Window : System.Address) is
   begin
      if Raw_Window = System.Null_Address then
         return;
      end if;

      if Registered_Drop_Windows.Is_Empty then
         return;
      end if;

      for Index in reverse Registered_Drop_Windows.First_Index .. Registered_Drop_Windows.Last_Index loop
         if Registered_Drop_Windows.Element (Index).Raw_Window = Raw_Window then
            Registered_Drop_Windows.Delete (Index);
            return;
         end if;
      end loop;
   end Unregister_Drop_Window;

   function Registered_Drop_Target
     (Raw_Window : System.Address)
      return Window_Access is
   begin
      if Raw_Window = System.Null_Address then
         return null;
      end if;

      for Registration of Registered_Drop_Windows loop
         if Registration.Raw_Window = Raw_Window then
            return Registration.Target;
         end if;
      end loop;

      return null;
   end Registered_Drop_Target;

   procedure Raw_Drop_Callback
     (Window : System.Address;
      Count  : Interfaces.C.int;
      Paths  : System.Address)
   is
      Target : constant Window_Access := Registered_Drop_Target (Window);
   begin
      if Target = null or else Paths = System.Null_Address or else Count <= 0 then
         return;
      end if;

      declare
         Raw_Paths : constant C_Path_Array_Pointers.Object_Pointer :=
           C_Path_Array_Pointers.To_Pointer (Paths);
         Last      : constant Natural :=
           --  One past the limit, so Queue can tell an oversized drop apart.
           Natural'Min (Natural (Count), Files.Drop_Events.Profile.Max_Paths + 1);
         Drops     : Files.Types.String_Vectors.Vector;
      begin
         if Raw_Paths = null then
            return;
         end if;

         for Index in 1 .. Last loop
            if Raw_Paths.all (Index) /= Interfaces.C.Strings.Null_Ptr then
               declare
                  Path : constant String := Interfaces.C.Strings.Value (Raw_Paths.all (Index));
               begin
                  Drops.Append (To_Unbounded_String (Path));
               end;
            end if;
         end loop;

         Files.Drop_Events.Queue (Target.Drop_Source, Drops);
      end;
   exception
      --  This is a Convention => C callback invoked from GLFW's C stack; an
      --  exception must never unwind through C frames. Swallow anything.
      when others =>
         null;
   end Raw_Drop_Callback;

   function To_Glfw_Key (Key : Tracked_Key) return Glfw.Input.Keys.Key;

   function Text_Input_Bytes
     (Char : Wide_Wide_Character)
      return String
   is
      Code : constant Natural := Wide_Wide_Character'Pos (Char);
   begin
      --  Drop control characters (text-input policy); Guikit.Utf8.Encode returns
      --  "" for surrogates and out-of-range values.
      if Code < Character'Pos (' ') then
         return "";
      end if;
      return Guikit.Utf8.Encode (Code);
   end Text_Input_Bytes;

   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character)
   is
      Bytes    : constant String := Text_Input_Bytes (Char);
      Parallel : constant Boolean := Object.Last_Was_Tracked_Press;
   begin
      Object.Last_Was_Tracked_Press := False;
      if Bytes = "" then
         return;
      end if;
      --  Plain typing coalesces into one event; a key's own character stays
      --  separate so a consumed shortcut can drop exactly that character.
      if not Parallel
        and then not Object.Pending_Input.Is_Empty
        and then Object.Pending_Input.Last_Element.Kind = Text_Event
        and then not Object.Pending_Input.Last_Element.Parallel
      then
         declare
            Last : Input_Event renames Object.Pending_Input (Object.Pending_Input.Last_Index);
         begin
            Append (Last.Text, Bytes);
         end;
      elsif Natural (Object.Pending_Input.Length) < Max_Pending_Input_Events then
         Object.Pending_Input.Append
           (Input_Event'(Kind => Text_Event, Text => To_Unbounded_String (Bytes), Parallel => Parallel, others => <>));
      end if;
   end Character_Entered;

   --  The key a press means under the active keyboard layout. GLFW names keys
   --  by their US-layout position, so on QWERTZ the key labelled Z arrives as
   --  Y and Ctrl+Z ran Redo. A printable key whose layout character is a
   --  letter is taken as that letter; every other key keeps its position
   --  (digits and punctuation already have position-based bindings, such as
   --  the zoom keys).
   function Layout_Key
     (Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode)
      return Glfw.Input.Keys.Key
   is
      function Get_Key_Name
        (Key_Value : Interfaces.C.int; Scancode_Value : Interfaces.C.int)
         return Interfaces.C.Strings.chars_ptr
        with Import, Convention => C, External_Name => "glfwGetKeyName";
      use type Glfw.Input.Keys.Key;
      Name : Interfaces.C.Strings.chars_ptr;
   begin
      if Key = Glfw.Input.Keys.Unknown then
         return Key;
      end if;
      Name := Get_Key_Name
        (Interfaces.C.int (Glfw.Input.Keys.Key'Enum_Rep (Key)), Interfaces.C.int (Scancode));
      if Name = Interfaces.C.Strings.Null_Ptr then
         return Key;
      end if;
      declare
         Text : constant String := Interfaces.C.Strings.Value (Name);
      begin
         if Text'Length = 1 and then Text (Text'First) in 'a' .. 'z' | 'A' .. 'Z' then
            return Glfw.Input.Keys.Key'Val
              (Glfw.Input.Keys.Key'Pos (Glfw.Input.Keys.A)
               + Character'Pos (Files.Types.To_Lower (Text) (1)) - Character'Pos ('a'));
         end if;
      end;
      return Key;
   exception
      when others =>
         return Key;
   end Layout_Key;

   overriding procedure Key_Changed
     (Object   : not null access Desktop_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers)
   is
      use type Glfw.Input.Keys.Action;
      use type Glfw.Input.Keys.Key;
   begin
      Object.Last_Was_Tracked_Press := False;
      if Action /= Glfw.Input.Keys.Press then
         return;
      end if;
      declare
         Meant : constant Glfw.Input.Keys.Key := Layout_Key (Key, Scancode);
         Held  : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      begin
         Held (Guikit.Input.Shift_Key) := Mods.Shift;
         Held (Guikit.Input.Control_Key) := Mods.Control;
         Held (Guikit.Input.Alt_Key) := Mods.Alt;
         Held (Guikit.Input.Meta_Key) := Mods.Super;
         for T in Tracked_Key loop
            if To_Glfw_Key (T) = Meant then
               if Natural (Object.Pending_Input.Length) < Max_Pending_Input_Events then
                  Object.Pending_Input.Append
                    (Input_Event'
                       (Kind => Key_Press_Event, Key => T, Physical => Key, Modifiers => Held, others => <>));
                  Object.Last_Was_Tracked_Press := True;
               end if;
               exit;
            end if;
         end loop;
      end;
   end Key_Changed;

   overriding procedure Mouse_Scrolled
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Scroll_Offset;
      Y      : Glfw.Input.Mouse.Scroll_Offset) is
      pragma Unreferenced (X);
   begin
      Object.Pending_Scroll :=
        Add_Pending_Scroll
          (Object.Pending_Scroll,
           Accumulate_Scroll_Offset (Object.Pending_Scroll_Remainder, Long_Float (Y)));
   end Mouse_Scrolled;

   overriding procedure Mouse_Button_Changed
     (Object : not null access Desktop_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers)
   is
      pragma Unreferenced (Mods);
   begin
      if Button = Glfw.Input.Mouse.Right_Button then
         if State = Glfw.Input.Pressed then
            Object.Pending_Right_Clicks :=
              Natural'Min (Object.Pending_Right_Clicks + 1, 8);
         end if;
         return;
      elsif Button /= Glfw.Input.Mouse.Left_Button then
         return;
      end if;

      if State = Glfw.Input.Pressed then
         declare
            Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         begin
            --  Drop a press that follows the previous accepted one too closely to
            --  be a real click -- a switch bounce that would otherwise double-fire.
            if Now - Object.Last_Left_Press_Time < Left_Press_Debounce then
               --  The bounce's release came first and was counted. The button
               --  is physically down again, so withdraw that phantom release:
               --  left in place it ends a drag that is still being held.
               if Object.Pending_Left_Releases > 0 then
                  Object.Pending_Left_Releases := Object.Pending_Left_Releases - 1;
               end if;
               Object.Left_Mouse_Down := True;
               return;
            end if;
            Object.Last_Left_Press_Time := Now;
         end;

         Object.Pending_Left_Clicks := Natural'Min (Object.Pending_Left_Clicks + 1, 8);
         Object.Left_Mouse_Down := True;
         Object.Drag_Start_X := Object.Last_Mouse_X;
         Object.Drag_Start_Y := Object.Last_Mouse_Y;
         Object.Drag_Moved := False;
      else
         Object.Pending_Left_Releases := Natural'Min (Object.Pending_Left_Releases + 1, 8);
         Object.Left_Mouse_Down := False;
      end if;
   end Mouse_Button_Changed;

   overriding procedure Mouse_Position_Changed
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate)
   is
      Delta_X : constant Glfw.Input.Mouse.Coordinate := X - Object.Drag_Start_X;
      Delta_Y : constant Glfw.Input.Mouse.Coordinate := Y - Object.Drag_Start_Y;
      Drag_Threshold : constant Glfw.Input.Mouse.Coordinate := 6.0;
   begin
      Object.Last_Mouse_X := X;
      Object.Last_Mouse_Y := Y;

      if Object.Left_Mouse_Down
        and then (abs Delta_X >= Drag_Threshold or else abs Delta_Y >= Drag_Threshold)
      then
         Object.Drag_Moved := True;
      end if;
   end Mouse_Position_Changed;

   function To_Modifiers
     (Window : not null access Glfw.Windows.Window)
      return Guikit.Input.Modifier_Set
   is
      Result : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Result (Guikit.Input.Shift_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Shift) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Shift) = Glfw.Input.Pressed;
      Result (Guikit.Input.Control_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Control) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Control) = Glfw.Input.Pressed;
      Result (Guikit.Input.Alt_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Alt) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Alt) = Glfw.Input.Pressed;
      Result (Guikit.Input.Meta_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Super) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Super) = Glfw.Input.Pressed;
      return Result;
   end To_Modifiers;

   function To_Glfw_Key
     (Key : Tracked_Key)
      return Glfw.Input.Keys.Key is separate;

   function To_Key_Code
     (Key : Tracked_Key)
      return Guikit.Input.Key_Code is separate;

   procedure Refresh_Selection_Grid_Columns
     (Runtime : in out Runtime_Window)
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
   begin
      if Runtime.Handle = null then
         return;
      end if;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);

      declare
         procedure Apply (Snapshot : Files.Rendering.View_Snapshot) is
            Layout    : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H),
                 Cell_Height_For (Runtime.Font_Pixel_Size));
            Main_View : constant Files.Rendering.Main_View_Layout :=
              Files.Rendering.Calculate_Main_View_Layout
                (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size));
         begin
            Files.Model.Set_Selection_Grid_Columns (Runtime.Model, Main_View.Columns);
         end Apply;
      begin
         --  Runs before every key fire, auto-repeat included. The last
         --  rendered snapshot is current unless the model or settings moved
         --  since, so reuse it rather than rebuilding O(items) per keystroke.
         if Runtime.Frame_Cache_Valid
           and then Runtime.Cached_Model_Revision = Files.Model.Revision (Runtime.Model)
           and then Files.Settings.Same_Snapshot_Settings (Runtime.Settings, Runtime.Cached_Settings_Key)
         then
            Apply (Runtime.Cached_Snapshot);
         else
            Apply (Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings));
         end if;
      end;
   end Refresh_Selection_Grid_Columns;

   --  Dispatch one tracked key press.
   --
   --  @param Runtime Window receiving the key.
   --  @param Key Tracked key, already resolved through the keyboard layout.
   --  @param Modifiers Modifiers held with the key.
   --  @param Consumed True when the key's own character must be dropped.
   procedure Fire_Key
     (Runtime   : in out Runtime_Window;
      Key       : Tracked_Key;
      Modifiers : Guikit.Input.Modifier_Set;
      Consumed  : out Boolean)
 is separate;

   procedure Dispatch_Text
     (Runtime : in out Runtime_Window;
      Text    : String)
   is
      Result : Files.Controller.Controller_Result;
   begin
      --  When the grid owns the keyboard this run feeds type-ahead; stamp the
      --  activity time so the inactivity timeout below measures from the last
      --  keystroke rather than from the previous field edit.
      if Files.Model.Focus (Runtime.Model) = Files.Types.Focus_None then
         Runtime.Type_Ahead_Input_At := Ada.Calendar.Clock;
      end if;

      Result := Files.Controller.Append_Focused_Text (Runtime.Model, Text);
      pragma Unreferenced (Result);
   end Dispatch_Text;

   --  Run the window's key presses and typed text in the order they arrived,
   --  then auto-repeat the repeating keys still held.
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window)
   is
      Events   : Input_Event_Vectors.Vector;
      Fired    : Pressed_Key_Map := [others => False];
      Consumed : Boolean := False;
      Now      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      Events := Runtime.Handle.Pending_Input;
      Runtime.Handle.Pending_Input.Clear;
      Runtime.Handle.Last_Was_Tracked_Press := False;

      for Event of Events loop
         case Event.Kind is
            when Key_Press_Event =>
               Runtime.Pressed_Keys (Event.Key) := True;
               Runtime.Key_Pressed_At (Event.Key) := Now;
               Runtime.Key_Last_Fired (Event.Key) := Now;
               Runtime.Held_Physical (Event.Key) := Event.Physical;
               Fired (Event.Key) := True;
               Fire_Key (Runtime, Event.Key, Event.Modifiers, Consumed);
            when Text_Event =>
               if not (Event.Parallel and then Consumed) then
                  Dispatch_Text (Runtime, To_String (Event.Text));
               end if;
               Consumed := False;
         end case;
      end loop;

      for Key in Tracked_Key loop
         if Runtime.Pressed_Keys (Key) then
            if Glfw.Windows.Key_State (As_Window (Runtime.Handle), Runtime.Held_Physical (Key)) /= Glfw.Input.Pressed
            then
               Runtime.Pressed_Keys (Key) := False;
            elsif not Fired (Key)
              and then Key_Repeats (Key)
              and then Now - Runtime.Key_Pressed_At (Key) >= Key_Repeat_Initial_Delay
              and then Now - Runtime.Key_Last_Fired (Key) >= Key_Repeat_Interval
            then
               Runtime.Key_Last_Fired (Key) := Now;
               Fire_Key (Runtime, Key, To_Modifiers (As_Window (Runtime.Handle)), Consumed);
            end if;
         end if;
      end loop;
   end Handle_Keyboard;

   --  Run one per-window step for every window, each behind its own exception
   --  boundary. A step that fails for one window's state must not starve the
   --  others of input, rendering, file watching or folder sizes, which a single
   --  handler around the whole loop pass did. The failing window's frame cache
   --  is dropped so its next frame is rebuilt rather than left stale.
   procedure For_Each_Window
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Step            : not null access procedure (Runtime : in out Runtime_Window)) is
   begin
      for Runtime of Runtime_Windows loop
         begin
            --  Keep the items in the drawn group order before any step reads
            --  or walks them; a no-op unless the model or grouping changed.
            Files.Model.Sync_Grouping (Runtime.Model, Runtime.Settings);
            Step (Runtime);
         exception
            when others =>
               Runtime.Frame_Cache_Valid := False;
         end;
      end loop;
   end For_Each_Window;

   procedure Handle_All_Keyboard
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Keyboard'Access);
   end Handle_All_Keyboard;

   --  Clear a stale grid type-ahead prefix once the user has paused. Driven from
   --  the event loop using the same Ada.Calendar clock as the key-repeat and
   --  file-watch timers, so a keystroke after the pause begins a fresh prefix.
   procedure Handle_Type_Ahead_Timeout
     (Runtime : in out Runtime_Window) is
   begin
      if Files.Model.Type_Ahead_Buffer (Runtime.Model) /= ""
        and then Ada.Calendar.Clock - Runtime.Type_Ahead_Input_At > Type_Ahead_Timeout
      then
         Files.Model.Reset_Type_Ahead (Runtime.Model);
      end if;
   end Handle_Type_Ahead_Timeout;

   procedure Handle_All_Type_Ahead_Timeout
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Type_Ahead_Timeout'Access);
   end Handle_All_Type_Ahead_Timeout;

   procedure Handle_Drop_Input
     (Runtime : in out Runtime_Window)
   is
      Result : Files.Controller.Controller_Result;
      Drops  : Files.Types.String_Vectors.Vector;
      Mode   : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      if Files.Drop_Events.Take_Overflow (Runtime.Handle.Drop_Source) then
         Files.Model.Set_Error (Runtime.Model, "error.drop.failed");
         return;
      end if;
      if not Files.Drop_Events.Has_Pending (Runtime.Handle.Drop_Source) then
         return;
      end if;

      Files.Drop_Events.Take (Runtime.Handle.Drop_Source, Drops, Mode);
      Result := Files.Controller.Handle_Drop_Import (Runtime.Model, Runtime.Settings, Drops, Mode);
      pragma Unreferenced (Result);
   end Handle_Drop_Input;

   procedure Handle_All_Drop_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Drop_Input'Access);
   end Handle_All_Drop_Input;

   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh_Jobs.Watch_Session) is
   begin
      Files.Model.Cancel_Folder_Scan (Model);
      Files.Model.Clear_Paste_Execution (Model);
      Files.Refresh_Jobs.Cancel (Model);
      Files.Refresh_Jobs.Release_Watch (Watch);
   end Release_Window_Jobs;

   function Drain_Native_Watch
     (Runtime : in out Runtime_Window)
      return Boolean is
   begin
      --  Native registration and storage reads happen in the helper process.
      Files.Refresh_Jobs.Watch_Path
        (Runtime.Watch, Files.Model.Current_Path (Runtime.Model));

      return Files.Refresh_Jobs.Poll_Watch (Runtime.Watch);
   end Drain_Native_Watch;

   procedure Handle_File_Watch_Poll
     (Runtime : in out Runtime_Window)
   is
      Now    : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Result : Files.Operations.Operation_Result;
      Refreshed : Boolean;
      pragma Unreferenced (Refreshed);
   begin
      if Runtime.Handle = null then
         return;
      end if;
      if not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
        or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle))
      then
         Release_Window_Jobs (Runtime.Model, Runtime.Watch);
         return;
      end if;

      if Files.Model.Paste_Execution_Is_Active (Runtime.Model) then
         Files.Refresh_Jobs.Cancel (Runtime.Model);
         return;
      end if;
      Refreshed := Files.Refresh_Jobs.Advance (Runtime.Model, Runtime.Settings);
      Files.Refresh_Jobs.Resume_Owed (Runtime.Model, Runtime.Settings);
      --  Also service selections deferred by a cancelled or failed refresh.
      Files.Model.Ensure_Selected_Item_Extra (Runtime.Model);

      if Drain_Native_Watch (Runtime) then
         declare
            Native_Result : Files.Operations.Operation_Result;
         begin
            Native_Result := Files.Operations.Refresh_If_Changed (Runtime.Model, Runtime.Settings);
            pragma Unreferenced (Native_Result);
         end;
         return;
      end if;

      if Now - Runtime.Last_Watch_Poll < File_Watch_Poll_Interval then
         return;
      end if;

      Runtime.Last_Watch_Poll := Now;
      Result := Files.Operations.Refresh_If_Changed (Runtime.Model, Runtime.Settings);
      pragma Unreferenced (Result);
   end Handle_File_Watch_Poll;

   procedure Handle_All_File_Watch_Poll
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_File_Watch_Poll'Access);
   end Handle_All_File_Watch_Poll;

   --  Each window polls and publishes only its own folder measurements.
   procedure Poll_All_Folder_Sizes (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
      procedure Poll (Runtime : in out Runtime_Window) is
      begin
         if Runtime.Handle /= null then
            Files.Operations.Update_Folder_Size (Runtime.Model, Runtime.Settings);
            Files.Model.Poll_Folder_Sizes (Runtime.Model);
         end if;
      end Poll;
   begin
      For_Each_Window (Runtime_Windows, Poll'Access);
   end Poll_All_Folder_Sizes;

   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
 is separate;

   procedure Handle_All_Scroll_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Scroll_Input'Access);
   end Handle_All_Scroll_Input;

   --  Every window writes its whole settings model to the one shared file, so
   --  each must see the others' changes: otherwise closing (or zooming) a
   --  window with a stale copy silently reverts a theme, favourite or label
   --  changed in another. A window whose settings moved since the last sync
   --  hands them to every other window.
   procedure Sync_Settings_Across_Windows
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector)
   is
      use type Files.Settings.Settings_Model;
      Changed : Natural := 0;
   begin
      for Index in Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         if Runtime_Windows (Index).Settings /= Runtime_Windows (Index).Synced_Settings then
            Changed := Index;
            exit;
         end if;
      end loop;
      if Changed = 0 then
         return;
      end if;

      declare
         Shared : constant Files.Settings.Settings_Model := Runtime_Windows (Changed).Settings;
      begin
         for Runtime of Runtime_Windows loop
            if Runtime.Settings /= Shared then
               Runtime.Settings := Shared;
               Runtime.Frame_Cache_Valid := False;
            end if;
            Runtime.Synced_Settings := Shared;
         end loop;
      end;
   end Sync_Settings_Across_Windows;

   function Scale_Coordinate
     (Value  : Glfw.Input.Mouse.Coordinate;
      Source : Glfw.Size;
      Target : Glfw.Size)
      return Natural is
   begin
      if Value <= 0.0 or else Source = 0 or else Target = 0 then
         return 0;
      end if;

      declare
         Scaled : constant Long_Float :=
           Long_Float (Value) * Long_Float (Target) / Long_Float (Source);
      begin
         if Scaled <= 0.0 then
            return 0;
         elsif Scaled >= Long_Float (Target) then
            return Natural (Target);
         else
            return Natural (Scaled);
         end if;
      end;
   exception
      when Constraint_Error =>
         return 0;
   end Scale_Coordinate;

   function Scrollbar_Drag_Offset
     (Thumb_Top    : Natural;
      Track_Length : Natural;
      Thumb_Length : Natural;
      Maximum      : Natural)
      return Natural
   is
      Travel  : constant Natural :=
        (if Track_Length > Thumb_Length then Track_Length - Thumb_Length else 0);
      Clamped : constant Natural := Natural'Min (Thumb_Top, Travel);
   begin
      if Travel = 0 or else Maximum = 0 then
         return 0;
      end if;

      return
        Natural
          (Long_Long_Integer (Clamped)
             * Long_Long_Integer (Maximum)
             / Long_Long_Integer (Travel));
   end Scrollbar_Drag_Offset;

   function Cursor_Is_Inside_Window
     (X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate;
      Width  : Glfw.Size;
      Height : Glfw.Size)
      return Boolean is
   begin
      return Width > 0
        and then Height > 0
        and then X >= 0.0
        and then Y >= 0.0
        and then X < Glfw.Input.Mouse.Coordinate (Width)
        and then Y < Glfw.Input.Mouse.Coordinate (Height);
   exception
      when Constraint_Error =>
         return False;
   end Cursor_Is_Inside_Window;

   procedure Dispatch_Click_Action
     (Runtime  : in out Runtime_Window;
      Action   : Files.Events.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set)
   is
      Result : Files.Interaction.Interaction_Result;
   begin
      --  Scrollbar-drag begin updates the shell-owned drag tracking state and
      --  never mutates the model, so it stays here rather than in the reducer.
      if Action.Kind = Files.Events.Scrollbar_Drag_Begin_Input_Action then
         Runtime.Scrollbar_Drag_Target := Action.Scroll_Area;
         Runtime.Scrollbar_Drag_Anchor := Action.Scroll_Drag_Anchor;
         return;
      end if;

      --  Column-resize begin likewise arms shell-owned drag state; the continuous
      --  resize is applied per frame by Update_Column_Resize_Drag. The action's
      --  payload is packed into the shared fields (see the Input_Action comment).
      if Action.Kind = Files.Events.Column_Resize_Begin_Input_Action then
         if Action.Item_Index not in
           Files.Types.Detail_Column'Pos (Files.Types.Optional_Detail_Column'First)
             .. Files.Types.Detail_Column'Pos (Files.Types.Optional_Detail_Column'Last)
           or else Action.Scroll_Drag_Anchor < 0
         then
            return;
         end if;
         Runtime.Column_Resize_Active := True;
         Runtime.Column_Resize_Target := Files.Types.Detail_Column'Val (Action.Item_Index);
         Runtime.Column_Resize_Origin_X := Action.Cursor_Position;
         Runtime.Column_Resize_Origin_W := Action.Scroll_Drag_Anchor;
         return;
      end if;

      --  Column-reorder begin arms shell-owned drag state; the drop (or the
      --  sort fallback for a press without a drag) is applied per frame by
      --  Update_Column_Reorder_Drag. The payload is packed into the shared
      --  fields (see the Input_Action comment).
      if Action.Kind = Files.Events.Column_Reorder_Begin_Input_Action then
         if Action.Item_Index not in
           Files.Types.Detail_Column'Pos (Files.Types.Optional_Detail_Column'First)
             .. Files.Types.Detail_Column'Pos (Files.Types.Optional_Detail_Column'Last)
         then
            return;
         end if;
         Runtime.Column_Reorder_Active := True;
         Runtime.Column_Reorder_Target := Files.Types.Detail_Column'Val (Action.Item_Index);
         Runtime.Column_Reorder_Origin_X := Action.Cursor_Position;
         Runtime.Column_Reorder_Started := False;
         Runtime.Column_Reorder_Sort := Action.Command;
         return;
      end if;

      --  Marquee begin arms shell-owned rubber-band state; the continuous
      --  selection is applied per frame by Update_Marquee_Drag. The press point
      --  and additive flag are packed into the shared fields (see the
      --  Input_Action comment). The prior selection is snapshotted now so an
      --  additive drag can union against it without the per-frame reapply
      --  erasing it.
      if Action.Kind = Files.Events.Marquee_Begin_Input_Action then
         Runtime.Marquee_Active := True;
         Runtime.Marquee_Moved := False;
         Runtime.Marquee_Origin_X := Action.Cursor_Position;
         Runtime.Marquee_Origin_Y := Action.Settings_Field;
         Runtime.Marquee_Additive := Action.Toggle_Selection;
         Runtime.Marquee_Base := Files.Interaction.Selected_Visible_Indices (Runtime.Model);
         Runtime.Marquee_Rect_X := 0;
         Runtime.Marquee_Rect_Y := 0;
         Runtime.Marquee_Rect_W := 0;
         Runtime.Marquee_Rect_H := 0;
         return;
      end if;

      Files.Interaction.Apply_Input_Action
        (Model             => Runtime.Model,
         Settings          => Runtime.Settings,
         Settings_Path     => To_String (Runtime.Settings_Path),
         Action            => Action,
         Current_Font_Size => Runtime.Font_Pixel_Size,
         Modifiers         => Modifiers,
         Result            => Result);
      Apply_Interaction_Result (Runtime, Result);
   end Dispatch_Click_Action;

   function Current_Click_Action
     (Runtime   : in out Runtime_Window;
      Window_W  : Glfw.Size;
      Window_H  : Glfw.Size;
      Frame_W   : Glfw.Size;
      Frame_H   : Glfw.Size;
      Cursor_X  : Glfw.Input.Mouse.Coordinate;
      Cursor_Y  : Glfw.Input.Mouse.Coordinate;
      Modifiers : Guikit.Input.Modifier_Set)
      return Files.Events.Input_Action
   is
   begin
      if not Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H)
        or else Frame_W <= 0 or else Frame_H <= 0
      then
         return (Kind => Files.Events.No_Input_Action, others => <>);
      end if;

      declare
         X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
         Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
      begin
         return
           Files.Events.Translate_Click
             (Snapshot    => Snapshot,
              Frame       => Runtime.Cached_Frame,
              X           => X,
              Y           => Y,
              Width       => Natural (Frame_W),
              Height      => Natural (Frame_H),
              Modifiers   => Modifiers,
              Line_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
      end;
   end Current_Click_Action;

   function Selected_File_Paths
     (Model : Files.Model.Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Items  : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      Result : Files.Types.String_Vectors.Vector;
   begin
      for Item of Items loop
         Result.Append (Item.Full_Path);
      end loop;

      return Result;
   end Selected_File_Paths;

   procedure Handle_Item_Drop
     (Runtime      : in out Runtime_Window;
      Target_Index : Natural;
      Modifiers    : Guikit.Input.Modifier_Set)
   is
      Sources : constant Files.Types.String_Vectors.Vector := Selected_File_Paths (Runtime.Model);
      Mode    : constant Files.File_System.Drop_Import_Mode :=
        (if Modifiers (Guikit.Input.Control_Key) then Files.File_System.Drop_Copy else Files.File_System.Drop_Move);
      Result  : Files.Operations.Operation_Result;
   begin
      if Target_Index = 0
        or else Target_Index > Files.Model.Visible_Count (Runtime.Model)
        or else Sources.Is_Empty
      then
         return;
      end if;

      declare
         Target : constant Files.File_System.Directory_Item :=
           Files.Model.Visible_Item (Runtime.Model, Positive (Target_Index));
      begin
         if Target.Kind /= Files.Types.Directory_Item then
            return;
         end if;

         --  Route the drop onto a folder row through the paste engine so it
         --  gets the conflict dialog and progress/cancel overlay. From_Clipboard
         --  is False: a dropped move must not clear an unrelated clipboard.
         Result :=
           Files.Operations.Begin_Paste_To
             (Model          => Runtime.Model,
              Settings       => Runtime.Settings,
              Source_Paths   => Sources,
              Destination    => To_String (Target.Full_Path),
              Mode           => Mode,
              From_Clipboard => False);
      end;

      pragma Unreferenced (Result);
   end Handle_Item_Drop;

   procedure Handle_Mouse
     (Runtime : in out Runtime_Window)
 is separate;

   procedure Handle_All_Mouse
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Mouse'Access);
   end Handle_All_Mouse;

   function Frame_Text_Key
     (Frame : Files.Rendering.Frame_Commands)
      return Unbounded_String
   is
      Result : Unbounded_String;

      procedure Append_Text_Key
        (Command : Guikit.Draw.Text_Command)
      is
      begin
         Append (Result, Natural'Image (Command.X));
         Append (Result, ":");
         Append (Result, Natural'Image (Command.Y));
         Append (Result, ":");
         Append (Result, Natural'Image (Command.Width));
         Append (Result, ":");
         Append (Result, Natural'Image (Command.Height));
         Append (Result, ":");
         Append (Result, Guikit.Draw.Render_Color'Image (Command.Color));
         Append (Result, ":");
         Append (Result, (if Command.Italic then "i" else "r"));
         Append (Result, ":");
         Append (Result, Command.Text);
         Append (Result, ASCII.LF);
      end Append_Text_Key;
   begin
      for Command of Frame.Text loop
         Append_Text_Key (Command);
      end loop;

      for Command of Frame.Overlay_Text loop
         Append_Text_Key (Command);
      end loop;

      return Result;
   end Frame_Text_Key;

   procedure Release_Window (Runtime : in out Runtime_Window) is
   begin
      --  Stop helpers before settings writes or graphics shutdown can delay
      --  native cleanup. A cleared handle also prevents queued input dispatch.
      Release_Window_Jobs (Runtime.Model, Runtime.Watch);
      if Runtime.Handle = null then
         return;
      end if;
      if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
         declare
            Window_W : Glfw.Size := 0;
            Window_H : Glfw.Size := 0;
         begin
            Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
            if Window_W > 0 and then Window_H > 0
              and then (Runtime.Settings.Window_Width /= Natural (Window_W)
                        or else Runtime.Settings.Window_Height /= Natural (Window_H))
            then
               Runtime.Settings.Window_Width := Natural (Window_W);
               Runtime.Settings.Window_Height := Natural (Window_H);
               Persist_Settings (Runtime);
            end if;
         end;
      end if;
      Guikit.Vulkan.Shutdown (Runtime.Vulkan);
      if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
         Unregister_Drop_Window (Glfw.Windows.Drop.Raw_Handle (As_Window (Runtime.Handle)));
         Glfw.Windows.Destroy (As_Window (Runtime.Handle));
      end if;
      Free_Window (Runtime.Handle);
   end Release_Window;

   procedure Release_Closed_Windows (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null
           and then (not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
                     or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle)))
         then
            Release_Window (Runtime);
         end if;
      end loop;
   end Release_Closed_Windows;

   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      Files.Folder_Size.Cancel;
      for Runtime of Runtime_Windows loop
         Release_Window (Runtime);
      end loop;
      Runtime_Windows.Clear;
      Process_Text_Font_Ready := False;
      Process_Text_Font_Path := Null_Unbounded_String;
      Process_Text_Font_Size := 0;
   end Release_All;

   function Any_Window_Open
     (Runtime_Windows : Runtime_Window_Vectors.Vector)
      return Boolean is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null
           and then Glfw.Windows.Initialized (As_Window (Runtime.Handle))
           and then not Glfw.Windows.Should_Close (As_Window (Runtime.Handle))
         then
            return True;
         end if;
      end loop;

      return False;
   end Any_Window_Open;

   procedure Append_Runtime_Window
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Startup_Window  : Files.Application.Startup_Window;
      Settings        : Files.Settings.Settings_Model;
      Settings_Path   : Unbounded_String;
      Width           : Natural;
      Height          : Natural)
   is
      Handle : Window_Access := new Desktop_Window;
   begin
      Glfw.Windows.Init
        (Object => As_Window (Handle),
         Width  => Glfw.Size (Width),
         Height => Glfw.Size (Height),
         Title  => To_String (Startup_Window.Title));
      Glfw.Windows.Set_Title (As_Window (Handle), To_String (Startup_Window.Title));
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Char);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Key);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Button);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Position);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Scroll);
      Glfw.Windows.Icon.Set_Files_Icon (As_Window (Handle));
      Register_Drop_Window (Glfw.Windows.Drop.Raw_Handle (As_Window (Handle)), Handle);
      Glfw.Windows.Drop.Set_Drop_Callback (As_Window (Handle), Raw_Drop_Callback'Access);
      Glfw.Windows.Show (As_Window (Handle));
      Runtime_Windows.Append
        (Runtime_Window'
           (Handle          => Handle,
            Model           => Startup_Window.Model,
            Settings        => Settings,
            Synced_Settings => Settings,
            Settings_Path   => Settings_Path,
            Pressed_Keys    => [others => False],
            Key_Pressed_At  => [others => Key_Epoch],
            Key_Last_Fired  => [others => Key_Epoch],
            Held_Physical   => [others => Glfw.Input.Keys.Unknown],
            Left_Mouse_Down => False,
            Drag_Source_Index => 0,
            Scrollbar_Drag_Target => Files.Events.Scroll_Auto,
            Scrollbar_Drag_Anchor => 0,
            Column_Resize_Active => False,
            Column_Resize_Target => Files.Types.Modified_Column,
            Column_Resize_Origin_X => 0,
            Column_Resize_Origin_W => 0,
            Column_Reorder_Active => False,
            Column_Reorder_Target => Files.Types.Modified_Column,
            Column_Reorder_Origin_X => 0,
            Column_Reorder_Started => False,
            Column_Reorder_Sort => Files.Commands.No_Command,
            Marquee_Active   => False,
            Marquee_Origin_X => 0,
            Marquee_Origin_Y => 0,
            Marquee_Moved    => False,
            Marquee_Additive => False,
            Marquee_Base     => <>,
            Marquee_Rect_X   => 0,
            Marquee_Rect_Y   => 0,
            Marquee_Rect_W   => 0,
            Marquee_Rect_H   => 0,
            Last_Click_Item => 0,
            Last_Click_Time => Ada.Calendar.Time_Of (1901, 1, 1),
            Type_Ahead_Input_At => Ada.Calendar.Time_Of (1901, 1, 1),
            Text            => <>,
            Text_Ready      => False,
            Font_Pixel_Size => Settings.Font_Pixel_Size,
            Text_Font_Path  => Null_Unbounded_String,
            Text_Content_Key => Null_Unbounded_String,
            Text_Content_Font_Path => Null_Unbounded_String,
            Text_Glyph_Key => Null_Unbounded_String,
            Text_Glyphs => <>,
            Vulkan          => <>,
            Shown           => True,
            Fallback_Frames => 0,
            Frame_Cache_Valid    => False,
            Presented_Once             => False,
            Last_Present_Palette_Open  => False,
            Last_Present_Settings_Open => False,
            Present_Grace              => 0,
            Cached_Snapshot      => <>,
            Cached_Model_Revision => 0,
            Cached_Settings_Key  => <>,
            Cached_Frame         => <>,
            Cached_Frame_W       => 0,
            Cached_Frame_H       => 0,
            Cached_Line_Height   => 20,
            Cached_Hover_X       => 0,
            Cached_Hover_Y       => 0,
            Cached_Has_Hover     => False,
            Cached_Has_Press     => False,
            Cached_Drag_Item     => 0,
            Cached_Has_Drag      => False,
            Cached_Marquee_Active => False,
            Cached_Marquee_X     => 0,
            Cached_Marquee_Y     => 0,
            Cached_Marquee_W     => 0,
            Cached_Marquee_H     => 0,
            Cached_Minute        => 0,
            Last_Glyph_Count => 0,
            Last_Missing_Glyph_Count => 0,
            Last_Present_Status => Guikit.Vulkan.Vulkan_Not_Initialized,
            Last_Watch_Poll => Ada.Calendar.Time_Of (1901, 1, 1),
            Watch => <>));
      Files.Model.Set_Background_Transfers
        (Runtime_Windows.Reference (Runtime_Windows.Last_Index).Model, True);
   exception
      when others =>
         if Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Handle)) then
               Unregister_Drop_Window (Glfw.Windows.Drop.Raw_Handle (As_Window (Handle)));
               Glfw.Windows.Destroy (As_Window (Handle));
            end if;

            Free_Window (Handle);
         end if;

         raise Desktop_Error with "error.window.create";
   end Append_Runtime_Window;

   procedure Update_Scrollbar_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
 is separate;

   procedure Update_Column_Resize_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Mouse_Down : Boolean)
   is
      Result : Files.Interaction.Interaction_Result;
   begin
      if not Runtime.Column_Resize_Active then
         return;
      elsif not Mouse_Down or else Window_W = 0 or else Frame_W = 0 then
         Runtime.Column_Resize_Active := False;
         return;
      end if;

      Files.Interaction.Apply_Column_Resize
        (Settings      => Runtime.Settings,
         Settings_Path => To_String (Runtime.Settings_Path),
         Column        => Runtime.Column_Resize_Target,
         Origin_X      => Runtime.Column_Resize_Origin_X,
         Origin_Width  => Runtime.Column_Resize_Origin_W,
         Current_X     => Scale_Coordinate (Cursor_X, Window_W, Frame_W),
         Result        => Result);
      pragma Unreferenced (Result);
   end Update_Column_Resize_Drag;

   --  Minimum pointer travel, in frame pixels, before an armed header press
   --  becomes a reorder drag. Below it a press/release is treated as a sort
   --  click, matching the resize hot zone's grabbable-yet-forgiving feel.
   Column_Reorder_Threshold : constant := 6;

   procedure Update_Column_Reorder_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
   is
      X_Frame : Integer;
   begin
      if not Runtime.Column_Reorder_Active then
         return;
      elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Runtime.Column_Reorder_Active := False;
         Runtime.Column_Reorder_Started := False;
         Runtime.Column_Reorder_Sort := Files.Commands.No_Command;
         return;
      end if;

      X_Frame := Scale_Coordinate (Cursor_X, Window_W, Frame_W);

      if Mouse_Down then
         if abs (X_Frame - Runtime.Column_Reorder_Origin_X) > Column_Reorder_Threshold then
            Runtime.Column_Reorder_Started := True;
         end if;
         return;
      end if;

      --  Mouse released: end the gesture. A crossed threshold applies the
      --  reorder at the drop target; otherwise the press was a plain click and
      --  falls back to the column's sort command (if any), but only when the
      --  release still lands on the cell that was pressed.
      Runtime.Column_Reorder_Active := False;

      if not Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H) then
         Runtime.Column_Reorder_Started := False;
         Runtime.Column_Reorder_Sort := Files.Commands.No_Command;
         return;
      end if;

      if Runtime.Column_Reorder_Started then
         declare
            Y_Frame  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
            Drop     : constant Natural :=
              Files.Rendering.Details_Header_Drop_Index
                (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
            Result   : Files.Interaction.Interaction_Result;
         begin
            if Drop in Files.Types.Detail_Column_Index then
               Files.Interaction.Apply_Column_Reorder
                 (Settings      => Runtime.Settings,
                  Settings_Path => To_String (Runtime.Settings_Path),
                  Column        => Runtime.Column_Reorder_Target,
                  To_Index      => Drop,
                  Result        => Result);
               Apply_Interaction_Result (Runtime, Result);
            end if;
         end;
      elsif Runtime.Column_Reorder_Sort /= Files.Commands.No_Command then
         declare
            Y_Frame  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
            Cell     : constant Files.Rendering.Detail_Header_Cell :=
              Files.Rendering.Details_Header_Cell_At
                (Snapshot, Layout, Natural'Max (0, X_Frame), Y_Frame, Line_Height);
         begin
            if Cell.Present
              and then Cell.Column = Runtime.Column_Reorder_Target
              and then Cell.Command = Runtime.Column_Reorder_Sort
            then
               Dispatch_Click_Action
                 (Runtime,
                  (Kind    => Files.Events.Command_Input_Action,
                   Command => Runtime.Column_Reorder_Sort,
                   others  => <>),
                  Guikit.Input.No_Modifiers);
            end if;
         end;
      end if;

      Runtime.Column_Reorder_Started := False;
      Runtime.Column_Reorder_Sort := Files.Commands.No_Command;
   end Update_Column_Reorder_Drag;

   --  Minimum pointer travel, in frame pixels, before an armed empty-space press
   --  becomes a marquee. Below it the press/release is a plain empty-space click
   --  that leaves the selection untouched, matching the pre-marquee no-op.
   Marquee_Drag_Threshold : constant := 4;

   procedure Update_Marquee_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean)
 is separate;

   --  Pointer gestures are tracked outside the model so they can update every
   --  frame.  If a keyboard shortcut opens an overlay while the button remains
   --  held, cancel every background gesture before its next update; otherwise
   --  scrolling, selection, or column settings can continue changing invisibly.
   procedure Cancel_Background_Gestures_For_Overlay
     (Runtime : in out Runtime_Window)
   is
      use type Files.Events.Scroll_Target;
      --  The destination picker is modal, but its tree scrollbar belongs to the
      --  modal surface rather than the background. Preserve only that gesture;
      --  every file-grid drag and any scrollbar owned by covered content still
      --  gets canceled below.
      Keep_Tree_Scrollbar : constant Boolean :=
        Files.Model.Tree_Pick_Is_Active (Runtime.Model)
        and then Files.Model.Tree_Panel_Is_Open (Runtime.Model)
        and then Runtime.Scrollbar_Drag_Target = Files.Events.Scroll_Tree_Panel
        and then not Files.Model.Command_Palette_Is_Open (Runtime.Model)
        and then not Files.Model.Root_Selector_Is_Open (Runtime.Model)
        and then not Files.Model.Settings_Pane_Is_Open (Runtime.Model)
        and then not Files.Model.Sort_Menu_Is_Open (Runtime.Model)
        and then not Files.Model.Context_Menu_Is_Open (Runtime.Model)
        and then not Files.Model.Label_Picker_Is_Open (Runtime.Model)
        and then not Files.Model.Quick_Look_Is_Open (Runtime.Model)
        and then not Files.Model.Paste_Conflict_Is_Active (Runtime.Model)
        and then not Files.Model.Paste_Execution_Is_Active (Runtime.Model);
   begin
      if not Files.Model.Input_Owning_Overlay_Is_Open (Runtime.Model) then
         return;
      end if;

      Runtime.Drag_Source_Index := 0;
      if not Keep_Tree_Scrollbar then
         Runtime.Scrollbar_Drag_Target := Files.Events.Scroll_Auto;
         Runtime.Scrollbar_Drag_Anchor := 0;
      end if;
      Runtime.Column_Resize_Active := False;
      Runtime.Column_Reorder_Active := False;
      Runtime.Column_Reorder_Started := False;
      Runtime.Column_Reorder_Sort := Files.Commands.No_Command;
      Runtime.Marquee_Active := False;
      Runtime.Marquee_Moved := False;
      Runtime.Marquee_Base.Clear;
      Runtime.Marquee_Rect_X := 0;
      Runtime.Marquee_Rect_Y := 0;
      Runtime.Marquee_Rect_W := 0;
      Runtime.Marquee_Rect_H := 0;
   end Cancel_Background_Gestures_For_Overlay;

   --  Append a component overlay's draw commands (its rectangles, text, icons and
   --  accessibility nodes) onto the window frame.
   procedure Append_Overlay
     (Frame         : in out Files.Rendering.Frame_Commands;
      Rectangles    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Icons         : Guikit.Draw.Icon_Command_Vectors.Vector :=
        Guikit.Draw.Icon_Command_Vectors.Empty_Vector) is
   begin
      --  Panels (command palette, settings) draw into the overlay layer, which
      --  is composited after the main grid's rectangles, icons and text. Drawing
      --  them into the main layers instead let the grid's icons and text (later
      --  passes) paint over the opaque panel, so the grid showed through.
      for C of Rectangles loop
         Frame.Overlay_Rectangles.Append (C);
      end loop;
      for C of Text loop
         Frame.Overlay_Text.Append (C);
      end loop;
      --  These panels emit no icons today; keep them in the main icon layer so
      --  the (unchanged) atlas path handles any that appear. If a panel ever
      --  needs icons above its own background, route them through the overlay
      --  icon pass instead.
      for C of Icons loop
         Frame.Icons.Append (C);
      end loop;
      for N of Accessibility loop
         Frame.Accessibility.Append (N);
      end loop;
   end Append_Overlay;

   --  Prepare the topmost modal layer. Cached frames can already contain a
   --  tooltip, root selector, Quick Look, or another overlay; their rectangles
   --  and text are batched in separate GPU passes and therefore cannot safely
   --  interleave with a newer modal. Remove those visual and accessibility
   --  commands, retain ordinary grid icons, and dim the inactive file view.
   procedure Append_Modal_Backdrop
     (Frame  : in out Files.Rendering.Frame_Commands;
      Width  : Natural;
      Height : Natural)
   is
      Main_Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
   begin
      for Command of Frame.Icons loop
         if not Command.Overlay then
            Main_Icons.Append (Command);
         end if;
      end loop;
      Frame.Icons := Main_Icons;
      Frame.Overlay_Rectangles.Clear;
      Frame.Overlay_Text.Clear;
      Frame.Tooltips.Clear;
      Frame.Accessibility.Clear;

      if Width > 0 and then Height > 0 then
         Frame.Overlay_Rectangles.Append
           (Guikit.Draw.Rectangle_Command'
              (X      => 0,
               Y      => 0,
               Width  => Width,
               Height => Height,
               Color  => Guikit.Draw.Modal_Backdrop_Color));
      end if;
   end Append_Modal_Backdrop;

   procedure Render_Window
     (Runtime : in out Runtime_Window)
 is separate;

   procedure Render_All
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Render_Window'Access);
   end Render_All;

   function Any_Runtime_Frame_Rendered
     (Runtime_Windows : Runtime_Window_Vectors.Vector)
      return Boolean is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Last_Glyph_Count > 0
           and then Runtime.Last_Present_Status = Guikit.Vulkan.Vulkan_Presented
         then
            return True;
         end if;
      end loop;

      return False;
   end Any_Runtime_Frame_Rendered;

   function All_Runtime_Windows_Shown
     (Runtime_Windows : Runtime_Window_Vectors.Vector)
      return Boolean is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null
           and then Glfw.Windows.Initialized (As_Window (Runtime.Handle))
           and then not Runtime.Shown
         then
            return False;
         end if;
      end loop;

      return True;
   end All_Runtime_Windows_Shown;

   procedure Show_Unshown_Runtime_Windows
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null
           and then Glfw.Windows.Initialized (As_Window (Runtime.Handle))
           and then not Runtime.Shown
         then
            Glfw.Windows.Show (As_Window (Runtime.Handle));
            Runtime.Shown := True;
         end if;
      end loop;
   end Show_Unshown_Runtime_Windows;

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

   function Live_Display_Available return Boolean is
      Display         : constant String := Safe_Environment_Value ("DISPLAY");
      Wayland_Display : constant String := Safe_Environment_Value ("WAYLAND_DISPLAY");
      Comspec         : constant String := Safe_Environment_Value ("COMSPEC");
   begin
      return Display /= "" or else Wayland_Display /= "" or else Comspec /= "";
   end Live_Display_Available;

   function Vulkan_Runtime_Available return Boolean is
      Initialized : Boolean := False;
   begin
      Glfw.Init;
      Initialized := True;
      declare
         Supported : constant Boolean := Glfw.Windows.Vulkan.Supported;
      begin
         Glfw.Shutdown;
         return Supported;
      end;
   exception
      when others =>
         if Initialized then
            Glfw.Shutdown;
         end if;
         return False;
   end Vulkan_Runtime_Available;

   function Runtime_Capabilities return Desktop_Capabilities is
      Display : constant Boolean := Live_Display_Available;
      Vulkan  : constant Boolean := Vulkan_Runtime_Available;
      Drop_Profile : constant Files.Drop_Events.Drop_Event_Source_Profile := Files.Drop_Events.Profile;
   begin
      return
        (Display_Available       => Display,
         Vulkan_Available        => Vulkan,
         Headless_Rendering      => True,
         Live_Window_Smoke_Ready => Display and then Vulkan,
         Event_Translation_Model => True,
         Focus_Runtime_Model     => True,
         Resize_Runtime_Model    => True,
         Scroll_Runtime_Model    => True,
         Native_Drop_Callbacks   => Drop_Profile.Native_Drop_Callbacks,
         Native_Drop_Automation  => Drop_Profile.Event_Source_Backend,
         Directory_Watch_Polling => True,
         Native_File_Watching    => True);
   end Runtime_Capabilities;

   function Native_Drag_Automation_Profile_Of_Current_Runtime
      return Native_Drag_Automation_Profile is
   begin
      return
        (Portable_GLFW_Automation => Files.Drop_Events.Profile.Portable_GLFW_Automation,
         Native_Drop_Callbacks    => Files.Drop_Events.Profile.Native_Drop_Callbacks,
         Event_Source_Backend     => Files.Drop_Events.Profile.Event_Source_Backend,
         Queued_Drop_Imports      => Files.Drop_Events.Profile.Queued_Drop_Imports,
         Requires_OS_Event_Source => Files.Drop_Events.Profile.Requires_OS_Event_Source,
         Uses_Shell               => Files.Drop_Events.Profile.Uses_Shell,
         Max_Paths                => Files.Drop_Events.Profile.Max_Paths,
         Binding_Unit             => Files.Drop_Events.Profile.Binding_Unit);
   end Native_Drag_Automation_Profile_Of_Current_Runtime;

   function Accumulate_Scroll_Offset
     (Remainder : in out Long_Float;
      Offset    : Long_Float)
      return Integer
   is
      Whole_Float : Long_Float := 0.0;
      Whole       : Integer := 0;
   begin
      --  Native input is not trusted to contain a finite IEEE value. A NaN
      --  compares false to every bound and, if retained, would poison every
      --  later scroll event for this window.
      if Remainder /= Remainder or else Offset /= Offset then
         Remainder := 0.0;
         return 0;
      end if;

      declare
         Total : constant Long_Float := Remainder + Offset;
      begin
         if Total >= Long_Float (Integer'Last) then
            Remainder := 0.0;
            return Integer'Last;
         elsif Total <= Long_Float (Integer'First) then
            Remainder := 0.0;
            return Integer'First;
         elsif Total >= 1.0 then
            Whole_Float := Long_Float'Floor (Total);
         elsif Total <= -1.0 then
            Whole_Float := Long_Float'Ceiling (Total);
         else
            Remainder := Total;
            return 0;
         end if;

         Whole := Integer (Whole_Float);
         Remainder := Total - Long_Float (Whole);
         return Whole;
      end;
   end Accumulate_Scroll_Offset;

   function Add_Pending_Scroll
     (Current : Integer;
      Change  : Integer)
      return Integer is
   begin
      if Change > 0 and then Current > Integer'Last - Change then
         return Integer'Last;
      elsif Change < 0 and then Current < Integer'First - Change then
         return Integer'First;
      else
         return Current + Change;
      end if;
   end Add_Pending_Scroll;

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

   procedure Run
     (Startup : Files.Application.Startup_Result)
   is
      Runtime_Windows : Runtime_Window_Vectors.Vector;
      Initialized     : Boolean := False;
      Recovery_Reported : Boolean := False;
   begin
      if Startup.Windows.Is_Empty then
         return;
      end if;

      Glfw.Init;
      Initialized := True;
      Guikit.Vulkan.Configure_Window_Hints;

      --  Register with the host screen reader for the lifetime of this session.
      --  Render_Window publishes a tree every time it rebuilds a frame; the
      --  first tree gives the native provider the root it needs to register.
      --  Unsupported hosts retain the semantic validation fallback.
      Files.Accessibility.Start;

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           =>
              (if Startup.Settings.Window_Width > 0
               then Startup.Settings.Window_Width
               else 1024),
            Height          =>
              (if Startup.Settings.Window_Height > 0
               then Startup.Settings.Window_Height
               else 768));
      end loop;

      for Frame_Index in 1 .. 3 loop
         Guikit.Vulkan.Poll_Events;
         Render_All (Runtime_Windows);
         exit when All_Runtime_Windows_Shown (Runtime_Windows);
      end loop;

      if not All_Runtime_Windows_Shown (Runtime_Windows) then
         Show_Unshown_Runtime_Windows (Runtime_Windows);
         Guikit.Vulkan.Poll_Events;
         Render_All (Runtime_Windows);
      end if;
      Guikit.Vulkan.Poll_Events;

      while Any_Window_Open (Runtime_Windows) loop
         begin
            Guikit.Vulkan.Wait_For_Events (Event_Wait_Timeout);
            Release_Closed_Windows (Runtime_Windows);
            exit when not Any_Window_Open (Runtime_Windows);
            Handle_All_Keyboard (Runtime_Windows);
            Handle_All_Type_Ahead_Timeout (Runtime_Windows);
            Handle_All_Mouse (Runtime_Windows);
            Handle_All_Drop_Input (Runtime_Windows);
            Handle_All_Scroll_Input (Runtime_Windows);
            Sync_Settings_Across_Windows (Runtime_Windows);
            if not Recovery_Reported
              and then Files.Job_Scavenger.Has_Unrecoverable
            then
               for Runtime of Runtime_Windows loop
                  if Runtime.Handle /= null then
                     Files.Model.Set_Error
                       (Runtime.Model, "error.recovery.unsafe_transport");
                     Runtime.Frame_Cache_Valid := False;
                  end if;
               end loop;
               Recovery_Reported := True;
            end if;
            Render_All (Runtime_Windows);
            Handle_All_File_Watch_Poll (Runtime_Windows);
            Poll_All_Folder_Sizes (Runtime_Windows);
         exception
            --  Resilience: a stray error while handling one frame's input or
            --  rendering should not tear down every window. Skip the frame and
            --  keep the event loop running. (The Wait above paces the loop, so
            --  this cannot become a tight busy-spin.)
            when others =>
               null;
         end;
      end loop;

      Files.Accessibility.Stop;
      Release_All (Runtime_Windows);
      Glfw.Shutdown;
   exception
      when Desktop_Error =>
         Files.Accessibility.Stop;
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise;
      when others =>
         Files.Accessibility.Stop;
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise Desktop_Error with "error.window.create";
   end Run;

end Files.Application.Windows;
