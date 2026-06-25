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

with Files.Command_Palette;
with Files.Commands;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
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
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Item_Kind;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Rendering.Vulkan.Vulkan_Status;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;

   type Desktop_Window is new Glfw.Windows.Window with record
      Pending_Text : Unbounded_String;
      Pending_Scroll : Integer := 0;
      Pending_Scroll_Remainder : Long_Float := 0.0;
      Pending_Left_Clicks : Natural := 0;
      Pending_Left_Releases : Natural := 0;
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

   type Tracked_Key is
     (Tracked_Key_1,
      Tracked_Key_2,
      Tracked_Key_3,
      Tracked_Key_4,
      Tracked_A,
      Tracked_D,
      Tracked_F,
      Tracked_L,
      Tracked_N,
      Tracked_P,
      Tracked_R,
      Tracked_S,
      Tracked_Comma,
      Tracked_Backspace,
      Tracked_Delete,
      Tracked_F2,
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
      Tracked_Page_Down);

   type Pressed_Key_Map is array (Tracked_Key) of Boolean;

   type Runtime_Window is record
      Handle          : Window_Access;
      Model           : Files.Model.Window_Model;
      Settings        : Files.Settings.Settings_Model;
      Settings_Path   : Unbounded_String;
      Pressed_Keys    : Pressed_Key_Map := [others => False];
      Left_Mouse_Down : Boolean := False;
      Drag_Source_Index : Natural := 0;
      Last_Click_Item : Natural := 0;
      Last_Click_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Text            : Files.Rendering.Text_Renderer;
      Text_Ready      : Boolean := False;
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

   Process_Text_Font_Ready : Boolean := False;
   Process_Text_Font_Path  : Unbounded_String;
   File_Watch_Poll_Interval : constant Duration := 1.0;
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

   function Execute_Runtime_Command
     (Runtime  : in out Runtime_Window;
      Command  : Files.Commands.Command_Id;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Files.Controller.Controller_Result
   is
      Settings_Path : constant String := To_String (Runtime.Settings_Path);
   begin
      if not Files.Commands.Is_Enabled (Command, Runtime.Model) then
         return
           Files.Controller.Execute_Command
             (Command, Runtime.Model, Runtime.Settings, Modifiers);
      end if;

      case Command is
         when Files.Commands.Save_Settings_Command =>
            return
              Files.Controller.Save_Settings
                (Runtime.Model, Runtime.Settings, Settings_Path);
         when others =>
            return Files.Controller.Execute_Command (Command, Runtime.Model, Runtime.Settings, Modifiers);
      end case;
   end Execute_Runtime_Command;

   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference is
   begin
      return Glfw.Windows.Window_Reference (Handle);
   end As_Window;

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
   end Raw_Drop_Callback;

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
      if Button /= Glfw.Input.Mouse.Left_Button then
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
         when Tracked_D =>
            return Glfw.Input.Keys.D;
         when Tracked_F =>
            return Glfw.Input.Keys.F;
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
         when Tracked_Comma =>
            return Glfw.Input.Keys.Comma;
         when Tracked_Backspace =>
            return Glfw.Input.Keys.Backspace;
         when Tracked_Delete =>
            return Glfw.Input.Keys.Delete;
         when Tracked_F2 =>
            return Glfw.Input.Keys.F2;
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
         when Tracked_D =>
            return Files.Types.Key_D;
         when Tracked_F =>
            return Files.Types.Key_F;
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
         when Tracked_Comma =>
            return Files.Types.Key_Comma;
         when Tracked_Backspace =>
            return Files.Types.Key_Backspace;
         when Tracked_Delete =>
            return Files.Types.Key_Delete;
         when Tracked_F2 =>
            return Files.Types.Key_F2;
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
           Files.Rendering.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H));
         Main_View : constant Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout);
      begin
         Files.Model.Set_Selection_Grid_Columns (Runtime.Model, Main_View.Columns);
      end;
   end Refresh_Selection_Grid_Columns;

   procedure Handle_Pressed_Key
     (Runtime : in out Runtime_Window;
      Key     : Tracked_Key)
   is
      Pressed : Boolean;
      Result : Files.Controller.Controller_Result;
   begin
      if Runtime.Handle = null then
         return;
      end if;

      Pressed := Glfw.Windows.Key_State (As_Window (Runtime.Handle), To_Glfw_Key (Key)) = Glfw.Input.Pressed;
      if not Pressed then
         Runtime.Pressed_Keys (Key) := False;
         return;
      end if;

      if Runtime.Pressed_Keys (Key) then
         return;
      end if;

      Runtime.Pressed_Keys (Key) := True;
      Refresh_Selection_Grid_Columns (Runtime);
      Result :=
        Files.Controller.Handle_Key
          (Model     => Runtime.Model,
           Settings  => Runtime.Settings,
           Key       => To_Key_Code (Key),
           Modifiers => To_Modifiers (As_Window (Runtime.Handle)));
      if Result.Command = Files.Commands.Save_Settings_Command then
         Result := Execute_Runtime_Command (Runtime, Result.Command);
      end if;
      pragma Unreferenced (Result);
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
                (Snapshot => Snapshot,
                 X        => X,
                 Y        => Y,
                 Width    => Natural (Frame_W),
                 Height   => Natural (Frame_H),
                 Y_Offset => Offset);
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
      Result : Files.Controller.Controller_Result;
   begin
      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Files.Commands.Requires_Settings_Path (Action.Command) then
               Result := Execute_Runtime_Command (Runtime, Action.Command, Modifiers);
            else
               Result :=
                 Files.Controller.Handle_Command_Click
                   (Action.Command, Runtime.Model, Runtime.Settings, Modifiers);
            end if;
         when Files.Events.Item_Click_Input_Action =>
            Result :=
              Files.Controller.Handle_Item_Click
                (Model         => Runtime.Model,
                 Settings      => Runtime.Settings,
                 Visible_Index => Action.Item_Index,
                 Activate      => Action.Activate,
                 Modifiers     => Modifiers);
         when Files.Events.Root_Click_Input_Action =>
            Result :=
              Files.Controller.Handle_Root_Click
                (Runtime.Model, Runtime.Settings, Action.Root_Index);
         when Files.Events.Command_Result_Click_Input_Action =>
            declare
               Results : constant Files.Command_Palette.Result_Vectors.Vector :=
                 Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Runtime.Model), Runtime.Model);
            begin
               if Action.Result_Index > 0
                 and then Action.Result_Index <= Natural (Results.Length)
                 and then Files.Commands.Requires_Settings_Path
                   (Results.Element (Positive (Action.Result_Index)).Command)
               then
                  Files.Model.Set_Command_Palette_Selected_Index (Runtime.Model, Action.Result_Index);
                  if Results.Element (Positive (Action.Result_Index)).Enabled then
                     Result :=
                       Execute_Runtime_Command
                         (Runtime, Results.Element (Positive (Action.Result_Index)).Command, Modifiers);
                     if Result.Status /= Files.Controller.Controller_Ignored then
                        Files.Model.Close_Command_Palette (Runtime.Model);
                     end if;
                  else
                     Result :=
                       Files.Controller.Handle_Command_Result_Click
                         (Model        => Runtime.Model,
                          Settings     => Runtime.Settings,
                          Result_Index => Action.Result_Index,
                          Modifiers    => Modifiers);
                  end if;
               else
                  Result :=
                    Files.Controller.Handle_Command_Result_Click
                      (Model        => Runtime.Model,
                       Settings     => Runtime.Settings,
                       Result_Index => Action.Result_Index,
                       Modifiers    => Modifiers);
               end if;
            end;
         when Files.Events.Text_Click_Input_Action =>
            Result :=
              Files.Controller.Handle_Text_Click
                (Model           => Runtime.Model,
                 Target          => Action.Focus_Target,
                 Cursor_Position => Action.Cursor_Position);
         when Files.Events.Settings_Click_Input_Action =>
            Result :=
              Files.Controller.Handle_Settings_Click
                (Model  => Runtime.Model,
                 Field  => Action.Settings_Field,
                 Option => Action.Settings_Option);
         when Files.Events.Scroll_Input_Action =>
            Result :=
              Files.Controller.Handle_Targeted_Scroll
                (Runtime.Model, Action.Scroll_Area, Action.Scroll_Lines);
         when Files.Events.No_Input_Action
            | Files.Events.Selection_Input_Action =>
            Result := (Status => Files.Controller.Controller_Ignored, others => <>);
      end case;

      pragma Unreferenced (Result);
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
          (Snapshot  => Snapshot,
           X         => X,
           Y         => Y,
           Width     => Natural (Frame_W),
           Height    => Natural (Frame_H),
           Modifiers => Modifiers);
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

         Result :=
           Files.Operations.Import_Dropped_Paths_To
             (Model                 => Runtime.Model,
              Settings              => Runtime.Settings,
              Source_Paths          => Sources,
              Destination_Directory => To_String (Target.Full_Path),
              Mode                  => Mode);
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
           and then Runtime.Handle.Pending_Left_Releases = 0)
      then
         return;
      end if;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      while Runtime.Handle.Pending_Left_Clicks > 0 loop
         Runtime.Handle.Pending_Left_Clicks := Runtime.Handle.Pending_Left_Clicks - 1;

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
            Left_Mouse_Down => False,
            Drag_Source_Index => 0,
            Last_Click_Item => 0,
            Last_Click_Time => Ada.Calendar.Time_Of (1901, 1, 1),
            Text            => <>,
            Text_Ready      => False,
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

      declare
         Hover_X  : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Width);
         Hover_Y  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Height);
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => Natural (Width),
              Height      => Natural (Height),
              Line_Height => 20,
              Hover_X     => Hover_X,
              Hover_Y     => Hover_Y,
              Has_Hover   => Width > 0 and then Height > 0 and then Window_W > 0 and then Window_H > 0,
              Pressed_X   => Hover_X,
              Pressed_Y   => Hover_Y,
              Has_Press   => Mouse_Down,
              Drag_Item_Index => Runtime.Drag_Source_Index,
              Drag_X      => Hover_X,
              Drag_Y      => Hover_Y,
              Has_Drag    =>
                Mouse_Down
                and then Runtime.Drag_Source_Index /= 0
                and then Runtime.Handle.Drag_Moved);
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
                       Pixel_Size  => 16,
                       Cell_Width  => 10,
                       Cell_Height => 20);
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
                 Cell_Width  => 10,
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
                 Cell_Width  => 10,
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
                     Visible_Index      => 1));
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
                  if Runtime.Last_Present_Status = Files.Rendering.Vulkan.Vulkan_Presented then
                     Result.Frames_Presented := Result.Frames_Presented + 1;
                  end if;
                  Result.Framebuffer_Readback_Ready :=
                    Result.Framebuffer_Readback_Ready or else Diagnostics.Framebuffer_Readback_Ready;
                  if Diagnostics.Framebuffer_Readback_Ready then
                     Result.Last_Framebuffer_Hash := Diagnostics.Last_Framebuffer_Hash;
                     Result.Last_Framebuffer_Bytes := Diagnostics.Last_Framebuffer_Bytes;
                  end if;
               end;
            end if;
         end loop;
      end loop;

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
            Error_Key       => To_Unbounded_String ("error.window.create"));
   end Run_Live_Window_Smoke;

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
            Width           => 1024,
            Height          => 768);
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
         Wait_For_Events_Timeout (Event_Wait_Timeout);
         Handle_All_Keyboard (Runtime_Windows);
         Handle_All_Text_Input (Runtime_Windows);
         Handle_All_Mouse (Runtime_Windows);
         Handle_All_Drop_Input (Runtime_Windows);
         Handle_All_Scroll_Input (Runtime_Windows);
         Render_All (Runtime_Windows);
         Handle_All_File_Watch_Poll (Runtime_Windows);
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
