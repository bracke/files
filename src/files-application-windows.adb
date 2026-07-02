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

with Files.Commands;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.Interaction;
with Files.Operations;
with Files.Rendering;
with Files.Settings;
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
   use type Files.Types.Item_Kind;
   use type Files.Types.View_Mode;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Rendering.Vulkan.Vulkan_Status;
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
      Tracked_Space);

   type Tracked_Key_Counts is array (Tracked_Key) of Natural;

   type Desktop_Window is new Glfw.Windows.Window with record
      Pending_Text : Unbounded_String;
      Pending_Scroll : Integer := 0;
      Pending_Scroll_Remainder : Long_Float := 0.0;
      Pending_Left_Clicks : Natural := 0;
      Pending_Left_Releases : Natural := 0;
      Pending_Right_Clicks : Natural := 0;
      Pending_Key_Presses : Tracked_Key_Counts := [others => 0];
      Last_Mouse_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Last_Mouse_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Drag_Start_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Drag_Start_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Left_Mouse_Down : Boolean := False;
      Drag_Moved : Boolean := False;
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

   function Cell_Width_For  (Size : Positive) return Positive is
     (Positive'Max (1, Size * 3 / 4));
   function Cell_Height_For (Size : Positive) return Positive is
     (Positive'Max (1, Size * 5 / 4));

   type Runtime_Window is record
      Handle          : Window_Access;
      Model           : Files.Model.Window_Model;
      Settings        : Files.Settings.Settings_Model;
      Settings_Path   : Unbounded_String;
      Pressed_Keys    : Pressed_Key_Map := [others => False];
      Key_Pressed_At  : Key_Time_Map := [others => Key_Epoch];
      Key_Last_Fired  : Key_Time_Map := [others => Key_Epoch];
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
      Vulkan          : Files.Rendering.Vulkan.Vulkan_Renderer;
      Vulkan_Tried    : Boolean := False;
      Surface_Tried   : Boolean := False;
      Shown           : Boolean := False;
      Last_Frame_Width  : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Fallback_Frames : Natural := 0;
      --  Frame command caching: when none of the rendering inputs change
      --  between two Render_Window calls, skip the expensive layout and
      --  Build_Frame_Commands rebuild and reuse the previously built data.
      Frame_Cache_Valid    : Boolean := False;
      Cached_Snapshot      : Files.Rendering.View_Snapshot;
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
      Last_Glyph_Count : Natural := 0;
      Last_Missing_Glyph_Count : Natural := 0;
      Last_Present_Status : Files.Rendering.Vulkan.Vulkan_Status :=
        Files.Rendering.Vulkan.Vulkan_Not_Initialized;
      Last_Watch_Poll : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Native_Watch_FD : Interfaces.C.int := -1;
      Native_Watch_ID : Interfaces.C.int := -1;
      Native_Watch_Path : Unbounded_String;
      Native_Watch_Event_Count : Natural := 0;
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

   Process_Text_Font_Ready : Boolean := False;
   Process_Text_Font_Path  : Unbounded_String;
   File_Watch_Poll_Interval : constant Duration := 1.0;
   Type_Ahead_Timeout : constant Duration := 1.0;
   Event_Wait_Timeout : constant Interfaces.C.double := 0.016;
   Inotify_Nonblock : constant Interfaces.C.int := 2_048;
   Inotify_Cloexec : constant Interfaces.C.int := 524_288;
   Inotify_Event_Mask : constant Interfaces.C.unsigned :=
     16#00000004# or 16#00000008# or 16#00000040# or 16#00000080#
     or 16#00000100# or 16#00000200# or 16#00000400# or 16#00000800#
     or 16#00002000# or 16#00004000# or 16#01000000#;

   procedure Poll_Events
     with Import, Convention => C, External_Name => "glfwPollEvents";

   procedure Wait_For_Events_Timeout
     (Timeout : Interfaces.C.double)
   with Import, Convention => C, External_Name => "glfwWaitEventsTimeout";

   function Inotify_Init1
     (Flags : Interfaces.C.int)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "inotify_init1";

   function Inotify_Add_Watch
     (FD       : Interfaces.C.int;
      Pathname : Interfaces.C.Strings.chars_ptr;
      Mask     : Interfaces.C.unsigned)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "inotify_add_watch";

   function Inotify_Rm_Watch
     (FD : Interfaces.C.int;
      WD : Interfaces.C.int)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "inotify_rm_watch";

   function C_Read
     (FD    : Interfaces.C.int;
      Buf   : System.Address;
      Count : Interfaces.C.size_t)
      return Interfaces.C.long
   with Import, Convention => C, External_Name => "read";

   function C_Close
     (FD : Interfaces.C.int)
      return Interfaces.C.int
   with Import, Convention => C, External_Name => "close";

   procedure Set_Raw_Window_Hint
     (Target : Interfaces.C.int;
      Hint   : Interfaces.C.int)
     with Import, Convention => C, External_Name => "glfwWindowHint";

   --  Write UTF-8 text to the system text clipboard. The GLFWwindow* argument is
   --  retained for the historic signature; modern GLFW ignores it.
   procedure Set_Raw_Clipboard_String
     (Window : System.Address;
      Text   : Interfaces.C.Strings.chars_ptr)
     with Import, Convention => C, External_Name => "glfwSetClipboardString";

   procedure Configure_Vulkan_Window_Hints;

   procedure Free_Window is new Ada.Unchecked_Deallocation
     (Object => Desktop_Window,
      Name   => Window_Access);

   procedure Configure_Vulkan_Window_Hints is
      GLFW_Client_API : constant Interfaces.C.int := 16#00022001#;
      GLFW_No_API     : constant Interfaces.C.int := 0;
   begin
      Glfw.Windows.Hints.Reset_To_Defaults;
      Set_Raw_Window_Hint (GLFW_Client_API, GLFW_No_API);
      Glfw.Windows.Hints.Set_Resizable (True);
      Glfw.Windows.Hints.Set_Visible (False);
   end Configure_Vulkan_Window_Hints;

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
      if Result.Clear_Pending_Text and then Runtime.Handle /= null then
         Runtime.Handle.Pending_Text := Null_Unbounded_String;
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
           Natural'Min (Natural (Count), Files.Drop_Events.Profile.Max_Paths);
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

      function Byte (Value : Natural) return Character is
      begin
         return Character'Val (Value);
      end Byte;
   begin
      if Code < Character'Pos (' ')
        or else (Code >= 16#D800# and then Code <= 16#DFFF#)
        or else Code > 16#10FFFF#
      then
         return "";
      elsif Code <= 16#7F# then
         return String'(1 => Byte (Code));
      elsif Code <= 16#7FF# then
         return Byte (16#C0# + Code / 16#40#) &
           Byte (16#80# + Code mod 16#40#);
      elsif Code <= 16#FFFF# then
         return Byte (16#E0# + Code / 16#1000#) &
           Byte (16#80# + (Code / 16#40#) mod 16#40#) &
           Byte (16#80# + Code mod 16#40#);
      else
         return Byte (16#F0# + Code / 16#40000#) &
           Byte (16#80# + (Code / 16#1000#) mod 16#40#) &
           Byte (16#80# + (Code / 16#40#) mod 16#40#) &
           Byte (16#80# + Code mod 16#40#);
      end if;
   end Text_Input_Bytes;

   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character) is
   begin
      Append (Object.Pending_Text, Text_Input_Bytes (Char));
   end Character_Entered;

   overriding procedure Key_Changed
     (Object   : not null access Desktop_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers)
   is
      use type Glfw.Input.Keys.Action;
      use type Glfw.Input.Keys.Key;
      pragma Unreferenced (Scancode, Mods);
   begin
      if Action /= Glfw.Input.Keys.Press then
         return;
      end if;
      for T in Tracked_Key loop
         if To_Glfw_Key (T) = Key then
            Object.Pending_Key_Presses (T) :=
              Natural'Min (Object.Pending_Key_Presses (T) + 1, 16);
            exit;
         end if;
      end loop;
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
      return Files.Types.Modifier_Set
   is
      Result : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
   begin
      Result (Files.Types.Shift_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Shift) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Shift) = Glfw.Input.Pressed;
      Result (Files.Types.Control_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Control) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Control) = Glfw.Input.Pressed;
      Result (Files.Types.Alt_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Alt) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Alt) = Glfw.Input.Pressed;
      Result (Files.Types.Meta_Key) :=
        Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Left_Super) = Glfw.Input.Pressed
        or else Glfw.Windows.Key_State (Window, Glfw.Input.Keys.Right_Super) = Glfw.Input.Pressed;
      return Result;
   end To_Modifiers;

   function To_Glfw_Key
     (Key : Tracked_Key)
      return Glfw.Input.Keys.Key is
   begin
      case Key is
         when Tracked_Key_1 =>
            return Glfw.Input.Keys.Key_1;
         when Tracked_Key_2 =>
            return Glfw.Input.Keys.Key_2;
         when Tracked_Key_3 =>
            return Glfw.Input.Keys.Key_3;
         when Tracked_Key_4 =>
            return Glfw.Input.Keys.Key_4;
         when Tracked_A =>
            return Glfw.Input.Keys.A;
         when Tracked_B =>
            return Glfw.Input.Keys.B;
         when Tracked_C =>
            return Glfw.Input.Keys.C;
         when Tracked_D =>
            return Glfw.Input.Keys.D;
         when Tracked_F =>
            return Glfw.Input.Keys.F;
         when Tracked_I =>
            return Glfw.Input.Keys.I;
         when Tracked_L =>
            return Glfw.Input.Keys.L;
         when Tracked_N =>
            return Glfw.Input.Keys.N;
         when Tracked_P =>
            return Glfw.Input.Keys.P;
         when Tracked_R =>
            return Glfw.Input.Keys.R;
         when Tracked_S =>
            return Glfw.Input.Keys.S;
         when Tracked_V =>
            return Glfw.Input.Keys.V;
         when Tracked_X =>
            return Glfw.Input.Keys.X;
         when Tracked_Z =>
            return Glfw.Input.Keys.Z;
         when Tracked_Comma =>
            return Glfw.Input.Keys.Comma;
         when Tracked_Backspace =>
            return Glfw.Input.Keys.Backspace;
         when Tracked_Delete =>
            return Glfw.Input.Keys.Delete;
         when Tracked_F2 =>
            return Glfw.Input.Keys.F2;
         when Tracked_F5 =>
            return Glfw.Input.Keys.F5;
         when Tracked_Escape =>
            return Glfw.Input.Keys.Escape;
         when Tracked_Enter =>
            return Glfw.Input.Keys.Enter;
         when Tracked_Numpad_Enter =>
            return Glfw.Input.Keys.Numpad_Enter;
         when Tracked_Left =>
            return Glfw.Input.Keys.Left;
         when Tracked_Right =>
            return Glfw.Input.Keys.Right;
         when Tracked_Up =>
            return Glfw.Input.Keys.Up;
         when Tracked_Down =>
            return Glfw.Input.Keys.Down;
         when Tracked_Home =>
            return Glfw.Input.Keys.Home;
         when Tracked_End =>
            return Glfw.Input.Keys.Key_End;
         when Tracked_Page_Up =>
            return Glfw.Input.Keys.Page_Up;
         when Tracked_Page_Down =>
            return Glfw.Input.Keys.Page_Down;
         when Tracked_Equal =>
            return Glfw.Input.Keys.Equal;
         when Tracked_Minus =>
            return Glfw.Input.Keys.Minus;
         when Tracked_Right_Bracket =>
            return Glfw.Input.Keys.Right_Bracket;
         when Tracked_Slash =>
            return Glfw.Input.Keys.Slash;
         when Tracked_Numpad_Add =>
            return Glfw.Input.Keys.Numpad_Add;
         when Tracked_Numpad_Subtract =>
            return Glfw.Input.Keys.Numpad_Substract;
         when Tracked_Zero =>
            return Glfw.Input.Keys.Key_0;
         when Tracked_Space =>
            return Glfw.Input.Keys.Space;
      end case;
   end To_Glfw_Key;

   function To_Key_Code
     (Key : Tracked_Key)
      return Files.Types.Key_Code is
   begin
      case Key is
         when Tracked_Key_1 =>
            return Files.Types.Key_1;
         when Tracked_Key_2 =>
            return Files.Types.Key_2;
         when Tracked_Key_3 =>
            return Files.Types.Key_3;
         when Tracked_Key_4 =>
            return Files.Types.Key_4;
         when Tracked_A =>
            return Files.Types.Key_A;
         when Tracked_B =>
            return Files.Types.Key_B;
         when Tracked_C =>
            return Files.Types.Key_C;
         when Tracked_D =>
            return Files.Types.Key_D;
         when Tracked_F =>
            return Files.Types.Key_F;
         when Tracked_I =>
            return Files.Types.Key_I;
         when Tracked_L =>
            return Files.Types.Key_L;
         when Tracked_N =>
            return Files.Types.Key_N;
         when Tracked_P =>
            return Files.Types.Key_P;
         when Tracked_R =>
            return Files.Types.Key_R;
         when Tracked_S =>
            return Files.Types.Key_S;
         when Tracked_V =>
            return Files.Types.Key_V;
         when Tracked_X =>
            return Files.Types.Key_X;
         when Tracked_Z =>
            return Files.Types.Key_Z;
         when Tracked_Comma =>
            return Files.Types.Key_Comma;
         when Tracked_Backspace =>
            return Files.Types.Key_Backspace;
         when Tracked_Delete =>
            return Files.Types.Key_Delete;
         when Tracked_F2 =>
            return Files.Types.Key_F2;
         when Tracked_F5 =>
            return Files.Types.Key_F5;
         when Tracked_Escape =>
            return Files.Types.Key_Escape;
         when Tracked_Enter | Tracked_Numpad_Enter =>
            return Files.Types.Key_Return;
         when Tracked_Left =>
            return Files.Types.Key_Left;
         when Tracked_Right =>
            return Files.Types.Key_Right;
         when Tracked_Up =>
            return Files.Types.Key_Up;
         when Tracked_Down =>
            return Files.Types.Key_Down;
         when Tracked_Home =>
            return Files.Types.Key_Home;
         when Tracked_End =>
            return Files.Types.Key_End;
         when Tracked_Page_Up =>
            return Files.Types.Key_Page_Up;
         when Tracked_Page_Down =>
            return Files.Types.Key_Page_Down;
         --  The '+' family (physical '=', ']' and numpad '+') maps to Key_Equal
         --  and the '-' family (physical '-', '/' and numpad '-') to Key_Minus
         --  so the shared keyboard-zoom seam handles Ctrl+plus / Ctrl+minus.
         --  The alternate ']' and '/' positions cover layouts (e.g. German)
         --  where '+' and '-' sit on those physical keys.
         when Tracked_Equal | Tracked_Right_Bracket | Tracked_Numpad_Add =>
            return Files.Types.Key_Equal;
         when Tracked_Minus | Tracked_Slash | Tracked_Numpad_Subtract =>
            return Files.Types.Key_Minus;
         when Tracked_Zero =>
            return Files.Types.Key_0;
         when Tracked_Space =>
            return Files.Types.Key_Space;
      end case;
   end To_Key_Code;

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
         Snapshot  : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout    : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H),
              Cell_Height_For (Runtime.Font_Pixel_Size));
         Main_View : constant Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout
             (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size));
      begin
         Files.Model.Set_Selection_Grid_Columns (Runtime.Model, Main_View.Columns);
      end;
   end Refresh_Selection_Grid_Columns;

   procedure Handle_Pressed_Key
     (Runtime : in out Runtime_Window;
      Key     : Tracked_Key)
   is
      Pressed   : Boolean;
      Now       : Ada.Calendar.Time;
      Pending   : Natural;
      Fire_Count : Natural := 0;
   begin
      if Runtime.Handle = null then
         return;
      end if;

      --  Drain any press events the GLFW callback captured since last poll.
      --  This catches rapid press/release cycles that finish between frames.
      Pending := Runtime.Handle.Pending_Key_Presses (Key);
      Runtime.Handle.Pending_Key_Presses (Key) := 0;

      Pressed := Glfw.Windows.Key_State (As_Window (Runtime.Handle), To_Glfw_Key (Key)) = Glfw.Input.Pressed;
      if not Pressed then
         Runtime.Pressed_Keys (Key) := False;
         Fire_Count := Pending;
      else
         Now := Ada.Calendar.Clock;

         if not Runtime.Pressed_Keys (Key) then
            Runtime.Pressed_Keys (Key)   := True;
            Runtime.Key_Pressed_At (Key) := Now;
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := Natural'Max (Pending, 1);
         elsif Pending > 0 then
            --  Re-pressed without our seeing the release. Treat as fresh
            --  press(es) so the auto-repeat clock resets to the latest one.
            Runtime.Key_Pressed_At (Key) := Now;
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := Pending;
         elsif Key_Repeats (Key)
           and then Now - Runtime.Key_Pressed_At (Key) >= Key_Repeat_Initial_Delay
           and then Now - Runtime.Key_Last_Fired (Key) >= Key_Repeat_Interval
         then
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := 1;
         end if;
      end if;

      if Fire_Count = 0 then
         return;
      end if;

      --  Ctrl + Plus / Ctrl + Minus / Ctrl + 0 keyboard zoom now flows through
      --  the shared key seam (Files.Interaction.Handle_Key adjusts the font
      --  size in the settings model and reports Font_Size_Changed); the shell's
      --  Apply_Interaction_Result then syncs the live size and rebuilds glyphs.
      Refresh_Selection_Grid_Columns (Runtime);
      for I in 1 .. Fire_Count loop
         declare
            Result : Files.Interaction.Interaction_Result;
         begin
            --  Genuine live key dispatch flows through the testable seam: it
            --  runs the focus-aware controller and re-routes settings-path
            --  commands through Execute_Command. The follow-up (font-size sync,
            --  glyph rebuild, parallel character-event discard via
            --  Clear_Pending_Text) is applied here.
            Files.Interaction.Handle_Key
              (Model             => Runtime.Model,
               Settings          => Runtime.Settings,
               Settings_Path     => To_String (Runtime.Settings_Path),
               Key               => To_Key_Code (Key),
               Modifiers         => To_Modifiers (As_Window (Runtime.Handle)),
               Current_Font_Size => Runtime.Font_Pixel_Size,
               Result            => Result);
            Apply_Interaction_Result (Runtime, Result);
         end;
      end loop;
   end Handle_Pressed_Key;

   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window) is
   begin
      for Key in Tracked_Key loop
         Handle_Pressed_Key (Runtime, Key);
      end loop;
   end Handle_Keyboard;

   procedure Handle_All_Keyboard
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Keyboard (Runtime);
      end loop;
   end Handle_All_Keyboard;

   procedure Handle_Text_Input
     (Runtime : in out Runtime_Window)
   is
      Result : Files.Controller.Controller_Result;
      Text   : Unbounded_String;
   begin
      if Runtime.Handle = null or else Length (Runtime.Handle.Pending_Text) = 0 then
         return;
      end if;

      Text := Runtime.Handle.Pending_Text;
      Runtime.Handle.Pending_Text := Null_Unbounded_String;

      --  When the grid owns the keyboard this run feeds type-ahead; stamp the
      --  activity time so the inactivity timeout below measures from the last
      --  keystroke rather than from the previous field edit.
      if Files.Model.Focus (Runtime.Model) = Files.Types.Focus_None then
         Runtime.Type_Ahead_Input_At := Ada.Calendar.Clock;
      end if;

      Result := Files.Controller.Append_Focused_Text (Runtime.Model, To_String (Text));
      pragma Unreferenced (Result);
   end Handle_Text_Input;

   procedure Handle_All_Text_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Text_Input (Runtime);
      end loop;
   end Handle_All_Text_Input;

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
      for Runtime of Runtime_Windows loop
         Handle_Type_Ahead_Timeout (Runtime);
      end loop;
   end Handle_All_Type_Ahead_Timeout;

   procedure Handle_Drop_Input
     (Runtime : in out Runtime_Window)
   is
      Result : Files.Controller.Controller_Result;
      Drops  : Files.Types.String_Vectors.Vector;
      Mode   : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
   begin
      if Runtime.Handle = null or else not Files.Drop_Events.Has_Pending (Runtime.Handle.Drop_Source) then
         return;
      end if;

      Files.Drop_Events.Take (Runtime.Handle.Drop_Source, Drops, Mode);
      Result := Files.Controller.Handle_Drop_Import (Runtime.Model, Runtime.Settings, Drops, Mode);
      pragma Unreferenced (Result);
   end Handle_Drop_Input;

   procedure Handle_All_Drop_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Drop_Input (Runtime);
      end loop;
   end Handle_All_Drop_Input;

   procedure Release_Native_Watch
     (Runtime : in out Runtime_Window)
   is
      Ignored : Interfaces.C.int;
   begin
      if Runtime.Native_Watch_FD >= 0 and then Runtime.Native_Watch_ID >= 0 then
         Ignored := Inotify_Rm_Watch (Runtime.Native_Watch_FD, Runtime.Native_Watch_ID);
      end if;

      if Runtime.Native_Watch_FD >= 0 then
         Ignored := C_Close (Runtime.Native_Watch_FD);
      end if;
      pragma Unreferenced (Ignored);

      Runtime.Native_Watch_FD := -1;
      Runtime.Native_Watch_ID := -1;
      Runtime.Native_Watch_Path := Null_Unbounded_String;
   end Release_Native_Watch;

   procedure Ensure_Native_Watch
     (Runtime : in out Runtime_Window)
   is
      Path   : constant String := Files.Model.Current_Path (Runtime.Model);
      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
   begin
      if Path = "" or else To_String (Runtime.Native_Watch_Path) = Path then
         return;
      end if;

      Release_Native_Watch (Runtime);
      Runtime.Native_Watch_FD := Inotify_Init1 (Inotify_Nonblock + Inotify_Cloexec);
      if Runtime.Native_Watch_FD < 0 then
         Runtime.Native_Watch_FD := -1;
         return;
      end if;

      C_Path := Interfaces.C.Strings.New_String (Path);
      Runtime.Native_Watch_ID := Inotify_Add_Watch (Runtime.Native_Watch_FD, C_Path, Inotify_Event_Mask);
      Interfaces.C.Strings.Free (C_Path);

      if Runtime.Native_Watch_ID < 0 then
         Release_Native_Watch (Runtime);
      else
         Runtime.Native_Watch_Path := To_Unbounded_String (Path);
      end if;
   exception
      when others =>
         if C_Path /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Path);
         end if;
         Release_Native_Watch (Runtime);
   end Ensure_Native_Watch;

   function Drain_Native_Watch
     (Runtime : in out Runtime_Window)
      return Boolean
   is
      Buffer : Interfaces.C.char_array (0 .. 4095);
      Count  : Interfaces.C.long;
      Changed : Boolean := False;
   begin
      Ensure_Native_Watch (Runtime);
      if Runtime.Native_Watch_FD < 0 then
         return False;
      end if;

      loop
         Count := C_Read (Runtime.Native_Watch_FD, Buffer'Address, Buffer'Length);
         exit when Count <= 0;
         Changed := True;
         Runtime.Native_Watch_Event_Count := Runtime.Native_Watch_Event_Count + 1;
      end loop;

      return Changed;
   exception
      when others =>
         Release_Native_Watch (Runtime);
         return False;
   end Drain_Native_Watch;

   procedure Handle_File_Watch_Poll
     (Runtime : in out Runtime_Window)
   is
      Now    : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Result : Files.Operations.Operation_Result;
   begin
      if Runtime.Handle = null then
         return;
      end if;

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
      for Runtime of Runtime_Windows loop
         Handle_File_Watch_Poll (Runtime);
      end loop;
   end Handle_All_File_Watch_Poll;

   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
   is
      Action : Files.Events.Input_Action;
      Result : Files.Controller.Controller_Result;
      Offset : Integer;
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
   begin
      if Runtime.Handle = null or else Runtime.Handle.Pending_Scroll = 0 then
         return;
      end if;

      Offset := Runtime.Handle.Pending_Scroll;
      Runtime.Handle.Pending_Scroll := 0;

      --  Ctrl + scroll: live font-size adjustment (zoom in / out).
      declare
         Modifiers : constant Files.Types.Modifier_Set :=
           To_Modifiers (As_Window (Runtime.Handle));
      begin
         if Modifiers (Files.Types.Control_Key) then
            declare
               New_Size : constant Positive :=
                 Files.Settings.Clamp_Font_Pixel_Size
                   (Integer (Runtime.Font_Pixel_Size) + Offset);
            begin
               if New_Size /= Runtime.Font_Pixel_Size then
                  Runtime.Font_Pixel_Size := New_Size;
                  Runtime.Settings.Font_Pixel_Size := Runtime.Font_Pixel_Size;
                  Runtime.Text_Ready := False;
                  Runtime.Text_Glyph_Key := Null_Unbounded_String;
                  Persist_Settings (Runtime);
               end if;
            end;
            return;
         end if;
      end;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      if Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Action := Files.Events.Translate_Scroll (Offset);
      else
         declare
            X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         begin
            Action :=
              Files.Events.Translate_Scroll_At
                (Snapshot    => Snapshot,
                 X           => X,
                 Y           => Y,
                 Width       => Natural (Frame_W),
                 Height      => Natural (Frame_H),
                 Y_Offset    => Offset,
                 Line_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
         end;
      end if;

      if Action.Kind = Files.Events.Scroll_Input_Action then
         Result :=
           Files.Controller.Handle_Targeted_Scroll
             (Runtime.Model, Action.Scroll_Area, Action.Scroll_Lines);
         pragma Unreferenced (Result);
      end if;
   end Handle_Scroll_Input;

   procedure Handle_All_Scroll_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Scroll_Input (Runtime);
      end loop;
   end Handle_All_Scroll_Input;

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

   procedure Dispatch_Click_Action
     (Runtime  : in out Runtime_Window;
      Action   : Files.Events.Input_Action;
      Modifiers : Files.Types.Modifier_Set)
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
      Modifiers : Files.Types.Modifier_Set)
      return Files.Events.Input_Action
   is
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
      Modifiers    : Files.Types.Modifier_Set)
   is
      Sources : constant Files.Types.String_Vectors.Vector := Selected_File_Paths (Runtime.Model);
      Mode    : constant Files.File_System.Drop_Import_Mode :=
        (if Modifiers (Files.Types.Control_Key) then Files.File_System.Drop_Copy else Files.File_System.Drop_Move);
      Result  : Files.Operations.Operation_Result;
   begin
      if Target_Index = 0 or else Sources.Is_Empty then
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
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
   begin
      if Runtime.Handle = null
        or else
          (Runtime.Handle.Pending_Left_Clicks = 0
           and then Runtime.Handle.Pending_Left_Releases = 0
           and then Runtime.Handle.Pending_Right_Clicks = 0)
      then
         return;
      end if;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      while Runtime.Handle.Pending_Right_Clicks > 0 loop
         Runtime.Handle.Pending_Right_Clicks := Runtime.Handle.Pending_Right_Clicks - 1;
         declare
            X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H),
                 Cell_Height_For (Runtime.Font_Pixel_Size));
            Item_Layout : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout
                (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size));
            In_Main : constant Boolean :=
              X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
              and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
            Item_Index : constant Natural :=
              (if In_Main then Files.Rendering.Item_At (Item_Layout, X, Y) else 0);
            In_Details_Header : constant Boolean :=
              Files.Rendering.Details_Header_Cell_At
                (Snapshot, Layout, X, Y, Cell_Height_For (Runtime.Font_Pixel_Size)).Present;
            Result : Files.Interaction.Interaction_Result;
         begin
            Files.Interaction.Apply_Right_Click
              (Model             => Runtime.Model,
               Settings          => Runtime.Settings,
               In_Main           => In_Main,
               Item_Index        => Item_Index,
               X                 => X,
               Y                 => Y,
               Result            => Result,
               In_Details_Header => In_Details_Header);
            Apply_Interaction_Result (Runtime, Result);
         end;
      end loop;

      while Runtime.Handle.Pending_Left_Clicks > 0 loop
         Runtime.Handle.Pending_Left_Clicks := Runtime.Handle.Pending_Left_Clicks - 1;

         if Files.Model.Context_Menu_Is_Open (Runtime.Model) then
            declare
               X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
               Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
               Snapshot : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
               Menu     : constant Files.Rendering.Context_Menu_Layout :=
                 Files.Rendering.Calculate_Context_Menu_Layout
                   (Snapshot, Natural (Frame_W), Natural (Frame_H),
                    Cell_Height_For (Runtime.Font_Pixel_Size));
               Row      : constant Natural := Files.Rendering.Context_Menu_Row_At (Menu, X, Y);
               Modifiers : constant Files.Types.Modifier_Set :=
                 To_Modifiers (As_Window (Runtime.Handle));
               Command  : constant Files.Commands.Command_Id :=
                 (if Row > 0 and then Row <= Menu.Row_Count then Menu.Commands (Row)
                  else Files.Commands.No_Command);
               Result   : Files.Interaction.Interaction_Result;
            begin
               Files.Interaction.Apply_Context_Menu_Command
                 (Model             => Runtime.Model,
                  Settings          => Runtime.Settings,
                  Settings_Path     => To_String (Runtime.Settings_Path),
                  Command           => Command,
                  Current_Font_Size => Runtime.Font_Pixel_Size,
                  Modifiers         => Modifiers,
                  Result            => Result);
               Apply_Interaction_Result (Runtime, Result);
            end;
            goto Continue_Left_Click_Loop;
         end if;

         declare
            Now       : constant Ada.Calendar.Time := Ada.Calendar.Clock;
            Modifiers : constant Files.Types.Modifier_Set := To_Modifiers (As_Window (Runtime.Handle));
            Action    : constant Files.Events.Input_Action :=
              Current_Click_Action
                (Runtime, Window_W, Window_H, Frame_W, Frame_H, Cursor_X, Cursor_Y, Modifiers);
            Activate  : constant Boolean :=
              Action.Kind = Files.Events.Item_Click_Input_Action
              and then Action.Item_Index = Runtime.Last_Click_Item
              and then Now - Runtime.Last_Click_Time <= 0.5;
         begin
            if Action.Kind = Files.Events.Item_Click_Input_Action then
               Runtime.Last_Click_Item := Action.Item_Index;
               Runtime.Last_Click_Time := Now;
               Runtime.Drag_Source_Index := Action.Item_Index;
            else
               Runtime.Last_Click_Item := 0;
               Runtime.Drag_Source_Index := 0;
            end if;

            if Activate then
               declare
                  Activated_Action : Files.Events.Input_Action := Action;
               begin
                  Activated_Action.Activate := True;
                  Dispatch_Click_Action (Runtime, Activated_Action, Modifiers);
               end;
            else
               Dispatch_Click_Action (Runtime, Action, Modifiers);
            end if;
         end;

         <<Continue_Left_Click_Loop>>
         null;
      end loop;

      while Runtime.Handle.Pending_Left_Releases > 0 loop
         Runtime.Handle.Pending_Left_Releases := Runtime.Handle.Pending_Left_Releases - 1;

         if Runtime.Handle.Drag_Moved and then Runtime.Drag_Source_Index /= 0 then
            declare
               Modifiers : constant Files.Types.Modifier_Set := To_Modifiers (As_Window (Runtime.Handle));
               Action    : constant Files.Events.Input_Action :=
                 Current_Click_Action
                   (Runtime, Window_W, Window_H, Frame_W, Frame_H, Cursor_X, Cursor_Y, Modifiers);
            begin
               if Action.Kind = Files.Events.Item_Click_Input_Action
                 and then Action.Item_Index /= Runtime.Drag_Source_Index
               then
                  Handle_Item_Drop (Runtime, Action.Item_Index, Modifiers);
               end if;
            end;
         end if;

         Runtime.Drag_Source_Index := 0;
         Runtime.Handle.Drag_Moved := False;
      end loop;
   end Handle_Mouse;

   procedure Handle_All_Mouse
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Mouse (Runtime);
      end loop;
   end Handle_All_Mouse;

   function Frame_Text_Key
     (Frame : Files.Rendering.Frame_Commands)
      return Unbounded_String
   is
      Result : Unbounded_String;

      procedure Append_Text_Key
        (Command : Files.Rendering.Text_Command)
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
         Append (Result, Files.Rendering.Render_Color'Image (Command.Color));
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

   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null
           and then Glfw.Windows.Initialized (As_Window (Runtime.Handle))
         then
            declare
               Window_W : Glfw.Size := 0;
               Window_H : Glfw.Size := 0;
            begin
               Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
               if Window_W > 0 and then Window_H > 0
                 and then
                   (Runtime.Settings.Window_Width /= Natural (Window_W)
                    or else Runtime.Settings.Window_Height /= Natural (Window_H))
               then
                  Runtime.Settings.Window_Width := Natural (Window_W);
                  Runtime.Settings.Window_Height := Natural (Window_H);
                  Persist_Settings (Runtime);
               end if;
            end;
         end if;

         Files.Rendering.Vulkan.Shutdown (Runtime.Vulkan);
         Release_Native_Watch (Runtime);

         if Runtime.Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
               Unregister_Drop_Window (Glfw.Windows.Drop.Raw_Handle (As_Window (Runtime.Handle)));
               Glfw.Windows.Destroy (As_Window (Runtime.Handle));
            end if;

            declare
               Handle : Window_Access := Runtime.Handle;
            begin
               Free_Window (Handle);
            end;
         end if;
      end loop;

      Runtime_Windows.Clear;
      Process_Text_Font_Ready := False;
      Process_Text_Font_Path := Null_Unbounded_String;
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
            Settings_Path   => Settings_Path,
            Pressed_Keys    => [others => False],
            Key_Pressed_At  => [others => Key_Epoch],
            Key_Last_Fired  => [others => Key_Epoch],
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
            Vulkan_Tried    => False,
            Surface_Tried   => False,
            Shown           => True,
            Last_Frame_Width  => 0,
            Last_Frame_Height => 0,
            Fallback_Frames => 0,
            Frame_Cache_Valid    => False,
            Cached_Snapshot      => <>,
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
            Last_Glyph_Count => 0,
            Last_Missing_Glyph_Count => 0,
            Last_Present_Status => Files.Rendering.Vulkan.Vulkan_Not_Initialized,
            Last_Watch_Poll => Ada.Calendar.Time_Of (1901, 1, 1),
            Native_Watch_FD => -1,
            Native_Watch_ID => -1,
            Native_Watch_Path => Null_Unbounded_String,
            Native_Watch_Event_Count => 0));
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
   is
      use type Files.Events.Scroll_Target;
      pragma Unreferenced (Cursor_X);
   begin
      if Runtime.Scrollbar_Drag_Target = Files.Events.Scroll_Auto then
         return;
      elsif not Mouse_Down
        or else Window_W = 0 or else Window_H = 0
        or else Frame_W = 0 or else Frame_H = 0
      then
         Runtime.Scrollbar_Drag_Target := Files.Events.Scroll_Auto;
         return;
      end if;

      declare
         Y_Frame      : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Line_Height  : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot     : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);

         procedure Apply_Drag
           (Track_Y     : Natural;
            Track_H     : Natural;
            Thumb_H     : Natural;
            Content_H   : Natural;
            View_H      : Natural;
            Apply_Lines : access procedure (Lines : Natural))
         is
            Drag_Range    : constant Integer := Integer'Max (0, Integer (Track_H) - Integer (Thumb_H));
            Max_Scroll_Px : constant Integer := Integer'Max (0, Integer (Content_H) - Integer (View_H));
            Wanted_Top    : constant Integer := Integer (Y_Frame) - Runtime.Scrollbar_Drag_Anchor;
            Rel_Y         : Integer := Wanted_Top - Integer (Track_Y);
            Scroll_Px     : Integer := 0;
         begin
            if Drag_Range <= 0 or else Max_Scroll_Px <= 0 then
               return;
            end if;
            if Rel_Y < 0 then
               Rel_Y := 0;
            elsif Rel_Y > Drag_Range then
               Rel_Y := Drag_Range;
            end if;
            Scroll_Px :=
              Integer
                (Long_Long_Integer (Rel_Y)
                   * Long_Long_Integer (Max_Scroll_Px)
                   / Long_Long_Integer (Drag_Range));
            Apply_Lines.all (Natural'Max (0, Scroll_Px / Line_Height));
         end Apply_Drag;

         procedure Set_Main_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, Lines);
         end Set_Main_Lines;

         procedure Set_Info_Lines (Lines : Natural) is
         begin
            Files.Model.Set_Info_Pane_Scroll_Lines (Runtime.Model, Lines);
         end Set_Info_Lines;
      begin
         case Runtime.Scrollbar_Drag_Target is
            when Files.Events.Scroll_Main_View =>
               declare
                  Main_View : constant Files.Rendering.Main_View_Layout :=
                    Files.Rendering.Calculate_Main_View_Layout
                      (Snapshot, Layout, Line_Height);
               begin
                  if Main_View.Scrollbar_Visible then
                     Apply_Drag
                       (Track_Y     => Main_View.Scrollbar_Y,
                        Track_H     => Main_View.Scrollbar_Track_Height,
                        Thumb_H     => Main_View.Scrollbar_Height,
                        Content_H   => Main_View.Content_Height,
                        View_H      => Main_View.Scrollbar_Track_Height,
                        Apply_Lines => Set_Main_Lines'Access);
                  end if;
               end;
            when Files.Events.Scroll_Info_Pane =>
               declare
                  Info_Pane : constant Files.Rendering.Info_Pane_Layout :=
                    Files.Rendering.Calculate_Info_Pane_Layout
                      (Snapshot, Layout, Line_Height);
               begin
                  if Info_Pane.Scrollbar_Visible then
                     Apply_Drag
                       (Track_Y     => Info_Pane.Scrollbar_Y,
                        Track_H     => Info_Pane.Scrollbar_Track_Height,
                        Thumb_H     => Info_Pane.Scrollbar_Height,
                        Content_H   => Info_Pane.Content_Height,
                        View_H      => Info_Pane.Height,
                        Apply_Lines => Set_Info_Lines'Access);
                  end if;
               end;
            when others =>
               null;
         end case;
      end;
   end Update_Scrollbar_Drag;

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
      --  falls back to the column's sort command (if any).
      Runtime.Column_Reorder_Active := False;

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
         Dispatch_Click_Action
           (Runtime,
            (Kind    => Files.Events.Command_Input_Action,
             Command => Runtime.Column_Reorder_Sort,
             others  => <>),
            Files.Types.No_Modifiers);
      end if;
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
   is
      X_Frame : Integer;
      Y_Frame : Integer;
   begin
      if not Runtime.Marquee_Active then
         return;
      elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Runtime.Marquee_Active := False;
         return;
      end if;

      X_Frame := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
      Y_Frame := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);

      if not Mouse_Down then
         --  Released: end the gesture and stop drawing the rectangle, keeping
         --  whatever selection the drag produced. A press that never crossed the
         --  threshold left the selection untouched, so an empty-space click that
         --  did not drag stays a no-op.
         Runtime.Marquee_Active := False;
         Runtime.Marquee_Rect_W := 0;
         Runtime.Marquee_Rect_H := 0;
         return;
      end if;

      if not Runtime.Marquee_Moved then
         if abs (X_Frame - Runtime.Marquee_Origin_X) > Marquee_Drag_Threshold
           or else abs (Y_Frame - Runtime.Marquee_Origin_Y) > Marquee_Drag_Threshold
         then
            Runtime.Marquee_Moved := True;
         else
            return;
         end if;
      end if;

      declare
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot    : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Items       : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
         Rect_X      : Natural;
         Rect_Y      : Natural;
         Rect_W      : Natural;
         Rect_H      : Natural;
      begin
         Files.Rendering.Marquee_Rect
           (Start_X   => Natural'Max (0, Runtime.Marquee_Origin_X),
            Start_Y   => Natural'Max (0, Runtime.Marquee_Origin_Y),
            Current_X => Natural'Max (0, X_Frame),
            Current_Y => Natural'Max (0, Y_Frame),
            X         => Rect_X,
            Y         => Rect_Y,
            Width     => Rect_W,
            Height    => Rect_H);
         Files.Interaction.Apply_Marquee_Selection
           (Model    => Runtime.Model,
            Hits     =>
              Files.Rendering.Items_In_Rect (Items, Rect_X, Rect_Y, Rect_W, Rect_H),
            Additive => Runtime.Marquee_Additive,
            Base     => Runtime.Marquee_Base);
         Runtime.Marquee_Rect_X := Rect_X;
         Runtime.Marquee_Rect_Y := Rect_Y;
         Runtime.Marquee_Rect_W := Rect_W;
         Runtime.Marquee_Rect_H := Rect_H;
      end;
   end Update_Marquee_Drag;

   procedure Render_Window
     (Runtime : in out Runtime_Window)
   is
      Width    : Glfw.Size := 0;
      Height   : Glfw.Size := 0;
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Mouse_Down : Boolean := False;
   begin
      if Runtime.Handle = null
        or else not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
        or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle))
      then
         return;
      end if;

      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Width, Height);
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);
      Mouse_Down :=
        Glfw.Windows.Mouse_Button_State (As_Window (Runtime.Handle), Glfw.Input.Mouse.Left_Button) =
        Glfw.Input.Pressed;

      Update_Scrollbar_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);

      Update_Column_Resize_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Window_W   => Window_W,
         Frame_W    => Width,
         Mouse_Down => Mouse_Down);

      Update_Column_Reorder_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);

      Update_Marquee_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);

      --  Drive a long copy/move a few actions at a time so the UI stays
      --  responsive and the progress overlay animates. Small pastes have already
      --  finished (in Begin_Paste / Resolve_Paste_Conflict) and never get here.
      if Files.Model.Paste_Execution_Is_Active (Runtime.Model) then
         declare
            Progress : constant Files.Operations.Operation_Result :=
              Files.Operations.Advance_Paste_Execution (Runtime.Model, Runtime.Settings, 8);
            pragma Unreferenced (Progress);
         begin
            null;
         end;
      end if;

      declare
         Hover_X  : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Width);
         Hover_Y  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Height);
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Has_Hover_Now : constant Boolean :=
           Width > 0 and then Height > 0 and then Window_W > 0 and then Window_H > 0;
         Has_Drag_Now  : constant Boolean :=
           Mouse_Down
           and then Runtime.Drag_Source_Index /= 0
           and then Runtime.Handle.Drag_Moved;
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Inputs_Match : constant Boolean :=
           Runtime.Frame_Cache_Valid
           and then Runtime.Cached_Frame_W = Natural (Width)
           and then Runtime.Cached_Frame_H = Natural (Height)
           and then Runtime.Cached_Line_Height = Line_Height
           and then Runtime.Cached_Hover_X = Hover_X
           and then Runtime.Cached_Hover_Y = Hover_Y
           and then Runtime.Cached_Has_Hover = Has_Hover_Now
           and then Runtime.Cached_Has_Press = Mouse_Down
           and then Runtime.Cached_Drag_Item = Runtime.Drag_Source_Index
           and then Runtime.Cached_Has_Drag = Has_Drag_Now
           and then Runtime.Cached_Marquee_Active = Runtime.Marquee_Active
           and then Runtime.Cached_Marquee_X = Runtime.Marquee_Rect_X
           and then Runtime.Cached_Marquee_Y = Runtime.Marquee_Rect_Y
           and then Runtime.Cached_Marquee_W = Runtime.Marquee_Rect_W
           and then Runtime.Cached_Marquee_H = Runtime.Marquee_Rect_H;
      begin
         if not Inputs_Match or else Snapshot /= Runtime.Cached_Snapshot then
            Runtime.Cached_Snapshot := Snapshot;
            Runtime.Cached_Frame :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => Natural (Width),
                 Height      => Natural (Height),
                 Line_Height => Line_Height,
                 Hover_X     => Hover_X,
                 Hover_Y     => Hover_Y,
                 Has_Hover   => Has_Hover_Now,
                 Pressed_X   => Hover_X,
                 Pressed_Y   => Hover_Y,
                 Has_Press   => Mouse_Down,
                 Drag_Item_Index => Runtime.Drag_Source_Index,
                 Drag_X      => Hover_X,
                 Drag_Y      => Hover_Y,
                 Has_Drag    => Has_Drag_Now,
                 Marquee_Active => Runtime.Marquee_Active,
                 Marquee_X   => Runtime.Marquee_Rect_X,
                 Marquee_Y   => Runtime.Marquee_Rect_Y,
                 Marquee_W   => Runtime.Marquee_Rect_W,
                 Marquee_H   => Runtime.Marquee_Rect_H);
            Runtime.Cached_Frame_W := Natural (Width);
            Runtime.Cached_Frame_H := Natural (Height);
            Runtime.Cached_Line_Height := Line_Height;
            Runtime.Cached_Hover_X := Hover_X;
            Runtime.Cached_Hover_Y := Hover_Y;
            Runtime.Cached_Has_Hover := Has_Hover_Now;
            Runtime.Cached_Has_Press := Mouse_Down;
            Runtime.Cached_Drag_Item := Runtime.Drag_Source_Index;
            Runtime.Cached_Has_Drag := Has_Drag_Now;
            Runtime.Cached_Marquee_Active := Runtime.Marquee_Active;
            Runtime.Cached_Marquee_X := Runtime.Marquee_Rect_X;
            Runtime.Cached_Marquee_Y := Runtime.Marquee_Rect_Y;
            Runtime.Cached_Marquee_W := Runtime.Marquee_Rect_W;
            Runtime.Cached_Marquee_H := Runtime.Marquee_Rect_H;
            Runtime.Frame_Cache_Valid := True;
         end if;
      end;

      declare
         Frame : Files.Rendering.Frame_Commands renames Runtime.Cached_Frame;
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.Cached_Snapshot;
      begin
         Glfw.Windows.Set_Title (As_Window (Runtime.Handle), To_String (Snapshot.Current_Path));

         if not Runtime.Vulkan_Tried then
            declare
               Status : constant Files.Rendering.Vulkan.Vulkan_Status :=
                 Files.Rendering.Vulkan.Initialize (Runtime.Vulkan);
            begin
               Runtime.Vulkan_Tried := True;
               pragma Unreferenced (Status);
            end;
         end if;

         if Runtime.Vulkan_Tried
           and then not Runtime.Surface_Tried
           and then Files.Rendering.Vulkan.Ready (Runtime.Vulkan)
         then
            declare
               Status : constant Files.Rendering.Vulkan.Vulkan_Status :=
                 Files.Rendering.Vulkan.Create_Surface (Runtime.Vulkan, As_Window (Runtime.Handle));
            begin
               Runtime.Surface_Tried := True;
               pragma Unreferenced (Status);
            end;
         end if;

         if Runtime.Surface_Tried
           and then Files.Rendering.Vulkan.Surface_Ready (Runtime.Vulkan)
           and then
             (not Files.Rendering.Vulkan.Swapchain_Ready (Runtime.Vulkan)
              or else Runtime.Last_Frame_Width /= Natural (Width)
              or else Runtime.Last_Frame_Height /= Natural (Height))
         then
            Files.Rendering.Vulkan.Request_Swapchain_Recreate
              (Renderer => Runtime.Vulkan,
               Width    => Natural (Width),
               Height   => Natural (Height));
            Runtime.Last_Present_Status :=
              Files.Rendering.Vulkan.Configure_Swapchain
                (Renderer => Runtime.Vulkan,
                 Width    => Natural (Width),
                 Height   => Natural (Height));
            Runtime.Last_Frame_Width := Natural (Width);
            Runtime.Last_Frame_Height := Natural (Height);
         end if;

         declare
            Current_Text_Key : constant Unbounded_String := Frame_Text_Key (Frame);
            Frame_Font_Path  : Unbounded_String;
         begin
            if Current_Text_Key = Runtime.Text_Content_Key
              and then Length (Runtime.Text_Content_Font_Path) > 0
            then
               Frame_Font_Path := Runtime.Text_Content_Font_Path;
            else
               Frame_Font_Path := To_Unbounded_String (Files.Rendering.Font_Path_For_Frame (Frame));
               Runtime.Text_Content_Key := Current_Text_Key;
               Runtime.Text_Content_Font_Path := Frame_Font_Path;
               Runtime.Text_Ready := False;
               Runtime.Text_Glyph_Key := Null_Unbounded_String;
               Process_Text_Font_Ready := False;
            end if;

            if Runtime.Text_Ready
              and then
                (Runtime.Text_Font_Path /= Frame_Font_Path
                 or else not Process_Text_Font_Ready
                 or else Process_Text_Font_Path /= Frame_Font_Path)
            then
               Runtime.Text_Ready := False;
               Runtime.Text_Glyph_Key := Null_Unbounded_String;
            end if;

            if not Runtime.Text_Ready then
               declare
                  Status : constant Files.Rendering.Text_Render_Status :=
                    Files.Rendering.Initialize_Text
                      (Renderer    => Runtime.Text,
                       Font_Path   => To_String (Frame_Font_Path),
                       Pixel_Size  => Runtime.Font_Pixel_Size,
                       Cell_Width  => Cell_Width_For (Runtime.Font_Pixel_Size),
                       Cell_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
               begin
                  Runtime.Text_Ready := Status = Files.Rendering.Text_Render_Success;
                  Runtime.Text_Font_Path :=
                    (if Runtime.Text_Ready then Frame_Font_Path else Null_Unbounded_String);
                  Runtime.Text_Glyph_Key := Null_Unbounded_String;
                  Process_Text_Font_Ready := Runtime.Text_Ready;
                  Process_Text_Font_Path :=
                    (if Runtime.Text_Ready then Frame_Font_Path else Null_Unbounded_String);
               end;
            end if;

            if Runtime.Text_Ready then
               declare
                  Glyphs : Files.Rendering.Text_Render_Result;
               begin
                  if Runtime.Text_Glyph_Key = Current_Text_Key
                    and then Runtime.Text_Glyphs.Status = Files.Rendering.Text_Render_Success
                  then
                     Glyphs := Runtime.Text_Glyphs;
                     Glyphs.Atlas_Dirty := False;
                  else
                     Glyphs := Files.Rendering.Build_Text_Glyphs (Runtime.Text, Frame);
                     Runtime.Text_Glyphs := Glyphs;
                     Runtime.Text_Glyph_Key := Current_Text_Key;
                  end if;

                  declare
                     Batch : constant Files.Rendering.Vulkan.Submission_Batch :=
                       Files.Rendering.Vulkan.Build_Submission (Frame, Glyphs);
                  begin
                     Runtime.Last_Glyph_Count := Natural (Glyphs.Glyphs.Length);
                     Runtime.Last_Missing_Glyph_Count := Glyphs.Missing_Glyph_Count;
                     Runtime.Last_Present_Status := Files.Rendering.Vulkan.Present (Runtime.Vulkan, Batch);

                     if Runtime.Last_Present_Status =
                       Files.Rendering.Vulkan.Vulkan_Swapchain_Recreate_Needed
                     then
                        Runtime.Last_Present_Status :=
                          Files.Rendering.Vulkan.Configure_Swapchain
                            (Renderer => Runtime.Vulkan,
                             Width    => Natural (Width),
                             Height   => Natural (Height));
                        Runtime.Last_Frame_Width := Natural (Width);
                        Runtime.Last_Frame_Height := Natural (Height);
                        if Runtime.Last_Present_Status =
                          Files.Rendering.Vulkan.Vulkan_Swapchain_Ready
                        then
                           Runtime.Last_Present_Status :=
                             Files.Rendering.Vulkan.Present (Runtime.Vulkan, Batch);
                        end if;
                     end if;

                     if Runtime.Last_Present_Status /= Files.Rendering.Vulkan.Vulkan_Presented then
                        Runtime.Fallback_Frames := Runtime.Fallback_Frames + 1;
                     end if;
                  end;
               end;
            else
               Runtime.Last_Glyph_Count := 0;
               Runtime.Last_Missing_Glyph_Count := 0;
            end if;
         end;
      end;
   end Render_Window;

   procedure Render_All
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Render_Window (Runtime);
      end loop;
   end Render_All;

   function Any_Runtime_Frame_Rendered
     (Runtime_Windows : Runtime_Window_Vectors.Vector)
      return Boolean is
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Last_Glyph_Count > 0
           and then Runtime.Last_Present_Status = Files.Rendering.Vulkan.Vulkan_Presented
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
   is
      Result : Headless_Render_Quality_Result :=
        (Window_Count => Natural (Startup.Windows.Length),
         others       => <>);

      function Has_Toolbar_Icon
        (Frame : Files.Rendering.Frame_Commands)
         return Boolean is
      begin
         for Icon of Frame.Icons loop
            if Ada.Strings.Fixed.Index (To_String (Icon.Icon_Id), "toolbar-") = 1 then
               return True;
            end if;
         end loop;

         return False;
      end Has_Toolbar_Icon;
   begin
      if Startup.Windows.Is_Empty then
         Result.Error_Key := To_Unbounded_String ("runtime.smoke.no_windows");
         return Result;
      end if;

      for Startup_Window of Startup.Windows loop
         Result.Frame_Count := Result.Frame_Count + 1;

         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Startup_Window.Model, Startup.Settings);
            Frame    : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Snapshot    => Snapshot,
                 Width       => Width,
                 Height      => Height,
                 Line_Height => 20);
            Drag_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
            Text     : Files.Rendering.Text_Renderer;
            Text_Status : constant Files.Rendering.Text_Render_Status :=
              Files.Rendering.Initialize_Text
                (Renderer    => Text,
                 Font_Path   => Files.Rendering.Font_Path_For_Frame (Frame),
                 Pixel_Size  => 16,
                 Cell_Width  => 12,
                 Cell_Height => 20);
            Glyphs : Files.Rendering.Text_Render_Result;
         begin
            if Frame.Layout.Width = Width
              and then Frame.Layout.Height = Height
              and then not Frame.Rectangles.Is_Empty
            then
               Result.Nonblank_Frames := Result.Nonblank_Frames + 1;
            end if;

            if not Frame.Icons.Is_Empty then
               Result.Icon_Frames := Result.Icon_Frames + 1;
            end if;

            if Has_Toolbar_Icon (Frame) then
               Result.Toolbar_Icon_Frames := Result.Toolbar_Icon_Frames + 1;
            end if;

            if Drag_Snapshot.Items.Is_Empty then
               Drag_Snapshot.Items.Append
                 (Files.Rendering.Item_Snapshot'
                    (Name               => To_Unbounded_String ("quality-drag.txt"),
                     Filetype           => To_Unbounded_String ("text/plain"),
                     Filetype_Detail    => To_Unbounded_String ("text"),
                     Icon_Id            => To_Unbounded_String ("text"),
                     Kind               => Files.Types.Regular_File_Item,
                     Size_Available     => False,
                     Size               => 0,
                     Creation_Available => False,
                     Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Modified_Available => False,
                     Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Permissions        => Null_Unbounded_String,
                     Filetype_Extra     => Null_Unbounded_String,
                     Thumbnail_Available => False,
                     Thumbnail_Path      => Null_Unbounded_String,
                     Thumbnail_Width     => 0,
                     Thumbnail_Height    => 0,
                     Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
                     Metadata_Error     => False,
                     Error_Key          => Null_Unbounded_String,
                     Selected           => True,
                     Visible_Index      => 1,
                     Cut_Pending        => False,
                     Renaming           => False,
                     Rename_Value       => Null_Unbounded_String,
                     Rename_Cursor      => 0,
                     Is_Group_Header    => False,
                     Group_Label        => Null_Unbounded_String,
                     Is_Favorite        => False,
                     Label              => Files.Types.No_Label));
            end if;

            declare
               Drag_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Snapshot        => Drag_Snapshot,
                    Width           => Width,
                    Height          => Height,
                    Line_Height     => 20,
                    Hover_X         => Natural'Min (Width, 96),
                    Hover_Y         => Natural'Min (Height, 96),
                    Has_Hover       => Width > 0 and then Height > 0,
                    Drag_Item_Index => Drag_Snapshot.Items.First_Element.Visible_Index,
                    Drag_X          => Natural'Min (Width, 96),
                    Drag_Y          => Natural'Min (Height, 96),
                    Has_Drag        => Width > 0 and then Height > 0);
            begin
               if Natural (Drag_Frame.Icons.Length) > Natural (Frame.Icons.Length)
                 and then Natural (Drag_Frame.Rectangles.Length) > Natural (Frame.Rectangles.Length)
               then
                  Result.Drag_Preview_Frames := Result.Drag_Preview_Frames + 1;
               end if;
            end;

            if Text_Status = Files.Rendering.Text_Render_Success then
               Glyphs := Files.Rendering.Build_Text_Glyphs (Text, Frame);
               Result.Missing_Glyph_Count :=
                 Result.Missing_Glyph_Count + Glyphs.Missing_Glyph_Count;
               if Glyphs.Status = Files.Rendering.Text_Render_Success and then not Glyphs.Glyphs.Is_Empty then
                  Result.Text_Glyph_Frames := Result.Text_Glyph_Frames + 1;
               else
                  Result.Failed_Frames := Result.Failed_Frames + 1;
               end if;
            else
               Result.Failed_Frames := Result.Failed_Frames + 1;
            end if;
         exception
            when others =>
               Result.Failed_Frames := Result.Failed_Frames + 1;
         end;
      end loop;

      Result.Passed :=
        Result.Frame_Count = Result.Window_Count
        and then Result.Window_Count > 0
        and then Result.Failed_Frames = 0
        and then Result.Nonblank_Frames = Result.Window_Count
        and then Result.Text_Glyph_Frames = Result.Window_Count
        and then Result.Icon_Frames = Result.Window_Count
        and then Result.Toolbar_Icon_Frames = Result.Window_Count
        and then Result.Drag_Preview_Frames = Result.Window_Count
        and then Result.Missing_Glyph_Count = 0;

      Result.Error_Key :=
        To_Unbounded_String ((if Result.Passed then "runtime.smoke.ready" else "runtime.smoke.text_failed"));
      return Result;
   end Headless_Render_Quality_Report;

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
      Total       : constant Long_Float := Remainder + Offset;
      Whole_Float : Long_Float := 0.0;
      Whole       : Integer := 0;
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
         when Scenario_Large_Font =>
            return "large_font";
         when Scenario_Light_Theme =>
            return "light_theme";
         when Scenario_Details_View =>
            return "details_view";
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
   is
      Large_Font : constant Positive := Files.Settings.Max_Font_Pixel_Size - 1;
      Has_Item   : constant Boolean := Files.Model.Visible_Count (Runtime.Model) >= 1;
   begin
      case Scenario is
         when Scenario_Default =>
            null;

         when Scenario_Selection =>
            if Has_Item then
               Files.Model.Select_Visible (Runtime.Model, 1);
            end if;

         when Scenario_Scrolled =>
            Files.Model.Replace_Items
              (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
            Files.Model.Set_Main_View_Scroll_Lines
              (Runtime.Model, Scenario_Scroll_Lines);

         when Scenario_Context_Menu =>
            Files.Model.Open_Context_Menu
              (Model      => Runtime.Model,
               X          => 64,
               Y          => 96,
               Target     =>
                 (if Has_Item then Files.Model.Context_Menu_Item
                  else Files.Model.Context_Menu_Empty),
               Item_Index => (if Has_Item then 1 else 0));

         when Scenario_Palette =>
            Files.Model.Open_Command_Palette (Runtime.Model);

         when Scenario_Large_Font =>
            --  Jump to a size the baseline is not already using so the scaling
            --  path is exercised and the frame provably differs from default.
            declare
               Target : constant Positive :=
                 (if Runtime.Font_Pixel_Size >= Large_Font
                  then Files.Settings.Min_Font_Pixel_Size
                  else Large_Font);
            begin
               Runtime.Font_Pixel_Size := Target;
               Runtime.Settings.Font_Pixel_Size := Target;
            end;

         when Scenario_Light_Theme =>
            Runtime.Settings.Theme := Files.Settings.Theme_Light;

         when Scenario_Details_View =>
            --  Render the details layout, unless the startup already uses it
            --  (a user default), in which case switch to a large-icons layout
            --  so the view-mode relayout still provably changes the frame.
            if Files.Model.View_Mode_Of (Runtime.Model) = Files.Types.Details then
               Files.Model.Set_View_Mode (Runtime.Model, Files.Types.Large_Icons);
            else
               Files.Model.Set_View_Mode (Runtime.Model, Files.Types.Details);
            end if;
      end case;
   end Apply_Scenario;

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
   is
      Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
      Snapshot    : constant Files.Rendering.View_Snapshot :=
        Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
      Layout      : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Calculate_Layout (Snapshot, Frame_W, Frame_H, Line_Height);
   begin
      if Frame_W = 0 or else Frame_H = 0 or else Layout.Width = 0 then
         return (others => <>);
      end if;

      case Scenario is
         when Scenario_Default =>
            --  The toolbar band spans the frame top and always draws a distinct
            --  bar plus buttons/icons, so its layout rectangle must hold ink.
            if Layout.Toolbar_Height = 0 then
               return (others => <>);
            end if;
            return
              (Valid => True,
               X     => 0,
               Y     => 0,
               W     => Layout.Width,
               H     => Layout.Toolbar_Height);

         when Scenario_Selection =>
            --  The selected item's cell rectangle must hold ink: its icon,
            --  label and selection fill render there.
            declare
               Items        : constant Files.Rendering.Item_Layout_Vectors.Vector :=
                 Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
               Target_Index : Natural := 0;
            begin
               for Item of Snapshot.Items loop
                  if Item.Selected then
                     Target_Index := Item.Visible_Index;
                     exit;
                  end if;
               end loop;

               if Target_Index = 0 then
                  return (others => <>);
               end if;

               for Cell of Items loop
                  if Cell.Visible_Index = Target_Index
                    and then Cell.Width > 0
                    and then Cell.Height > 0
                  then
                     return
                       (Valid => True,
                        X     => Cell.X,
                        Y     => Cell.Y,
                        W     => Cell.Width,
                        H     => Cell.Height);
                  end if;
               end loop;

               return (others => <>);
            end;

         when others =>
            return (others => <>);
      end case;
   end Scenario_Region;

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
            Last_Status        => Files.Rendering.Vulkan.Vulkan_Not_Initialized,
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
         Last_Status        => Files.Rendering.Vulkan.Vulkan_Not_Initialized,
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
   is
      Runtime_Windows : Runtime_Window_Vectors.Vector;
      Initialized     : Boolean := False;
      Result          : Live_Smoke_Result := Evaluate_Live_Window_Smoke (Plan);
   begin
      if not Plan.Can_Run or else Startup.Windows.Is_Empty then
         if Startup.Windows.Is_Empty then
            Result.Error_Key := To_Unbounded_String ("runtime.smoke.no_windows");
         end if;
         return Result;
      end if;

      Result.Attempted := True;
      Result.Skipped_By_Plan := False;
      Glfw.Init;
      Initialized := True;
      Configure_Vulkan_Window_Hints;

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           => Plan.Width,
            Height          => Plan.Height);
      end loop;
      for Runtime of Runtime_Windows loop
         Files.Rendering.Vulkan.Set_Readback_Enabled (Runtime.Vulkan, True);
      end loop;

      Result.Window_Created := not Runtime_Windows.Is_Empty;
      for Poll_Index in 1 .. Plan.Input_Poll_Count loop
         Poll_Events;
         Handle_All_Keyboard (Runtime_Windows);
         Handle_All_Text_Input (Runtime_Windows);
         Handle_All_Mouse (Runtime_Windows);
         Handle_All_Drop_Input (Runtime_Windows);
         Handle_All_Scroll_Input (Runtime_Windows);
         Handle_All_File_Watch_Poll (Runtime_Windows);
         Result.Input_Polled := True;
      end loop;

      --  Capture the pristine per-window baseline so each scenario starts from
      --  the same startup state and any framebuffer difference is caused by the
      --  scenario alone.
      declare
         Bases : Scenario_Base_Vectors.Vector;
      begin
         for Runtime of Runtime_Windows loop
            Bases.Append
              (Scenario_Base_State'
                 (Model    => Runtime.Model,
                  Settings => Runtime.Settings,
                  Font     => Runtime.Font_Pixel_Size));
         end loop;

         --  Render every scenario in order within the one window/device, taking
         --  each scenario's structural verdict and framebuffer hash from the
         --  final frame's readback.
         for Scenario in Live_Smoke_Scenario loop
            declare
               Base_Index : Positive := 1;
               Outcome    : Scenario_Outcome := (others => <>);
            begin
               for Runtime of Runtime_Windows loop
                  Prepare_Scenario (Runtime, Bases (Base_Index), Scenario);
                  Base_Index := Base_Index + 1;
               end loop;

               for Frame_Index in 1 .. Plan.Frame_Count loop
                  Result.Frames_Attempted := Result.Frames_Attempted + 1;
                  Render_All (Runtime_Windows);
                  Result.Frame_Rendered :=
                    Result.Frame_Rendered or else Any_Runtime_Frame_Rendered (Runtime_Windows);
                  for Runtime of Runtime_Windows loop
                     if Runtime.Last_Present_Status /= Files.Rendering.Vulkan.Vulkan_Not_Initialized then
                        declare
                           Diagnostics : constant Files.Rendering.Vulkan.Renderer_Diagnostics :=
                             Files.Rendering.Vulkan.Diagnostics (Runtime.Vulkan);
                        begin
                           Result.Last_Status := Runtime.Last_Present_Status;
                           Result.Last_Vk_Result := Diagnostics.Last_Vk_Result;
                           Result.Vulkan_Device_Ready :=
                             Result.Vulkan_Device_Ready or else Diagnostics.Device_Ready;
                           if Runtime.Last_Present_Status = Files.Rendering.Vulkan.Vulkan_Presented then
                              Result.Frames_Presented := Result.Frames_Presented + 1;
                           end if;
                           if Diagnostics.Framebuffer_Readback_Ready then
                              Result.Framebuffer_Readback_Ready := True;
                              Result.Last_Framebuffer_Bytes := Diagnostics.Last_Framebuffer_Bytes;
                              Outcome.Rendered := True;
                              Outcome.Readback_Ready := True;
                              Outcome.Hash := Diagnostics.Last_Framebuffer_Hash;
                              Outcome.Passed := Diagnostics.Framebuffer_Passed;

                              --  Layout-derived region assertion: prove a
                              --  specific UI element rendered at the pixel
                              --  rectangle its layout computed. An empty region
                              --  where the structural Analyze still passed is
                              --  exactly what a coordinate/DPI-scaling
                              --  regression produces, so it fails the scenario.
                              declare
                                 Rect : constant Region_Rect :=
                                   Scenario_Region
                                     (Runtime, Scenario,
                                      Diagnostics.Frame_Width, Diagnostics.Frame_Height);
                              begin
                                 if Rect.Valid then
                                    Outcome.Region_Checked := True;
                                    Outcome.Region_Ink_Fraction :=
                                      Files.Rendering.Vulkan.Readback_Region_Ink_Fraction
                                        (Runtime.Vulkan, Rect.X, Rect.Y, Rect.W, Rect.H);
                                    Outcome.Region_Ink_Present :=
                                      Files.Rendering.Vulkan.Readback_Region_Has_Ink
                                        (Runtime.Vulkan, Rect.X, Rect.Y, Rect.W, Rect.H);
                                 end if;
                              end;

                              --  The default scenario feeds the legacy
                              --  single-frame diagnostics printout.
                              if Scenario = Scenario_Default then
                                 Result.Last_Framebuffer_Hash := Diagnostics.Last_Framebuffer_Hash;
                                 Result.Framebuffer_Analysis := Diagnostics.Framebuffer_Analysis;
                              end if;
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;

               Result.Scenario_Results (Scenario) := Outcome;
            end;
         end loop;
      end;

      --  Overall structural verdict: every scenario must pass and every
      --  non-default scenario's frame must differ from the default frame.
      Result.Framebuffer_Passed := Scenarios_Verdict (Result.Scenario_Results);

      Release_All (Runtime_Windows);
      Glfw.Shutdown;
      Result.Closed_Cleanly := True;
      Result.Error_Key :=
        To_Unbounded_String
          ((if Result.Frame_Rendered then "runtime.smoke.ready" else "runtime.smoke.text_failed"));
      return Result;
   exception
      when Desktop_Error =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         return
           (Attempted       => True,
            Window_Created  => Result.Window_Created,
            Frame_Rendered  => Result.Frame_Rendered,
            Frames_Attempted => Result.Frames_Attempted,
            Frames_Presented => Result.Frames_Presented,
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
            Last_Status     => Result.Last_Status,
            Last_Vk_Result  => Result.Last_Vk_Result,
            Framebuffer_Readback_Ready => Result.Framebuffer_Readback_Ready,
            Last_Framebuffer_Hash => Result.Last_Framebuffer_Hash,
            Last_Framebuffer_Bytes => Result.Last_Framebuffer_Bytes,
            Framebuffer_Analysis => Result.Framebuffer_Analysis,
            Framebuffer_Passed => Result.Framebuffer_Passed,
            Vulkan_Device_Ready => Result.Vulkan_Device_Ready,
            Scenario_Results => Result.Scenario_Results,
            Error_Key       => To_Unbounded_String ("error.window.create"));
      when others =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         return
           (Attempted       => True,
            Window_Created  => Result.Window_Created,
            Frame_Rendered  => Result.Frame_Rendered,
            Frames_Attempted => Result.Frames_Attempted,
            Frames_Presented => Result.Frames_Presented,
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
            Last_Status     => Result.Last_Status,
            Last_Vk_Result  => Result.Last_Vk_Result,
            Framebuffer_Readback_Ready => Result.Framebuffer_Readback_Ready,
            Last_Framebuffer_Hash => Result.Last_Framebuffer_Hash,
            Last_Framebuffer_Bytes => Result.Last_Framebuffer_Bytes,
            Framebuffer_Analysis => Result.Framebuffer_Analysis,
            Framebuffer_Passed => Result.Framebuffer_Passed,
            Vulkan_Device_Ready => Result.Vulkan_Device_Ready,
            Scenario_Results => Result.Scenario_Results,
            Error_Key       => To_Unbounded_String ("error.window.create"));
   end Run_Live_Window_Smoke;

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
   begin
      if Startup.Windows.Is_Empty then
         return;
      end if;

      Glfw.Init;
      Initialized := True;
      Configure_Vulkan_Window_Hints;

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
         Poll_Events;
         Render_All (Runtime_Windows);
         exit when All_Runtime_Windows_Shown (Runtime_Windows);
      end loop;

      if not All_Runtime_Windows_Shown (Runtime_Windows) then
         Show_Unshown_Runtime_Windows (Runtime_Windows);
         Poll_Events;
         Render_All (Runtime_Windows);
      end if;
      Poll_Events;

      while Any_Window_Open (Runtime_Windows) loop
         begin
            Wait_For_Events_Timeout (Event_Wait_Timeout);
            Handle_All_Keyboard (Runtime_Windows);
            Handle_All_Text_Input (Runtime_Windows);
            Handle_All_Type_Ahead_Timeout (Runtime_Windows);
            Handle_All_Mouse (Runtime_Windows);
            Handle_All_Drop_Input (Runtime_Windows);
            Handle_All_Scroll_Input (Runtime_Windows);
            Render_All (Runtime_Windows);
            Handle_All_File_Watch_Poll (Runtime_Windows);
         exception
            --  Resilience: a stray error while handling one frame's input or
            --  rendering should not tear down every window. Skip the frame and
            --  keep the event loop running. (The Wait above paces the loop, so
            --  this cannot become a tight busy-spin.)
            when others =>
               null;
         end;
      end loop;

      Release_All (Runtime_Windows);
      Glfw.Shutdown;
   exception
      when Desktop_Error =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise;
      when others =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise Desktop_Error with "error.window.create";
   end Run;

end Files.Application.Windows;
