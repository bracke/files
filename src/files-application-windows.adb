with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with Glfw.Input;
with Glfw.Input.Keys;
with Glfw.Windows;
with Glfw.Windows.Context;
with Glfw.Windows.Hints;
with Glfw.Windows.Vulkan;

with Files.Command_Palette;
with Files.Commands;
with Files.Events;
with Files.File_System;
with Files.Operations;
with Files.Platform.Dialogs;
with Files.Rendering;
with Files.Rendering.Vulkan;
with Files.Settings;
with Files.Types;

package body Files.Application.Windows is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Glfw.Input.Button_State;
   use type Glfw.Input.Mouse.Coordinate;
   use type Glfw.Size;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.Commands.Command_Id;
   use type Files.Operations.Operation_Status;
   use type Files.Rendering.Text_Render_Status;
   use type Files.Rendering.Vulkan.Vulkan_Status;

   type Desktop_Window is new Glfw.Windows.Window with record
      Pending_Text : Unbounded_String;
      Pending_Scroll : Integer := 0;
      Pending_Scroll_Remainder : Long_Float := 0.0;
   end record;

   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character);

   overriding procedure Mouse_Scrolled
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Scroll_Offset;
      Y      : Glfw.Input.Mouse.Scroll_Offset);

   type Window_Access is access all Desktop_Window;

   type Tracked_Key is
     (Tracked_Key_1,
      Tracked_Key_2,
      Tracked_Key_3,
      Tracked_Key_4,
      Tracked_D,
      Tracked_F,
      Tracked_L,
      Tracked_N,
      Tracked_P,
      Tracked_R,
      Tracked_S,
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
      Last_Click_Item : Natural := 0;
      Last_Click_Time : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Text            : Files.Rendering.Text_Renderer;
      Text_Ready      : Boolean := False;
      Vulkan          : Files.Rendering.Vulkan.Vulkan_Renderer;
      Vulkan_Tried    : Boolean := False;
      Surface_Tried   : Boolean := False;
      Last_Frame_Width  : Natural := 0;
      Last_Frame_Height : Natural := 0;
      Fallback_Frames : Natural := 0;
      Last_Present_Status : Files.Rendering.Vulkan.Vulkan_Status :=
        Files.Rendering.Vulkan.Vulkan_Not_Initialized;
   end record;

   package Runtime_Window_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Runtime_Window);

   procedure Poll_Events
     with Import, Convention => C, External_Name => "glfwPollEvents";

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

   function Execute_Runtime_Command
     (Runtime  : in out Runtime_Window;
      Command  : Files.Commands.Command_Id;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Files.Controller.Controller_Result
   is
      Settings_Path : constant String := To_String (Runtime.Settings_Path);

      function Dialog_No_Selection_Result
        (Dialog_Result : Native_File_Dialog_Result)
         return Files.Controller.Controller_Result
      is
         Error_Key : constant UString :=
           (if Length (Dialog_Result.Error_Key) > 0 then Dialog_Result.Error_Key
            else Null_Unbounded_String);
      begin
         if Length (Error_Key) > 0 then
            Files.Model.Set_Error (Runtime.Model, To_String (Error_Key));
            return
              (Status    => Files.Controller.Controller_Command_Executed,
               Command   => Command,
               Operation =>
                 (Status    => Files.Operations.Operation_Disabled,
                  Error_Key => Error_Key,
                  Path      => To_Unbounded_String (Settings_Path),
                  others    => <>));
         end if;

         return
           (Status    => Files.Controller.Controller_Ignored,
            Command   => Command,
            Operation => <>);
      end Dialog_No_Selection_Result;
   begin
      if not Files.Commands.Is_Enabled (Command, Runtime.Model) then
         return
           Files.Controller.Execute_Command
             (Command, Runtime.Model, Runtime.Settings, Modifiers);
      end if;

      case Command is
         when Files.Commands.Import_Settings_Command =>
            declare
               Request       : constant Native_File_Dialog_Request :=
                 Settings_Import_Dialog_Request (Settings_Path);
               Dialog_Result : constant Native_File_Dialog_Result :=
                 Open_Native_File_Dialog (Request);
               Selected_Path : constant String :=
                 To_String (Settings_Path_After_Dialog (Settings_Path, Request, Dialog_Result));
            begin
               if not Settings_Path_Selected (Dialog_Result) then
                  return Dialog_No_Selection_Result (Dialog_Result);
               end if;

               return Files.Controller.Import_Settings (Runtime.Model, Selected_Path);
            end;
         when Files.Commands.Export_Settings_Command =>
            declare
               Request       : constant Native_File_Dialog_Request :=
                 Settings_Export_Dialog_Request (Settings_Path);
               Dialog_Result : constant Native_File_Dialog_Result :=
                 Open_Native_File_Dialog (Request);
               Selected_Path : constant String :=
                 To_String (Settings_Path_After_Dialog (Settings_Path, Request, Dialog_Result));
            begin
               if not Settings_Path_Selected (Dialog_Result) then
                  return Dialog_No_Selection_Result (Dialog_Result);
               end if;

               return Files.Controller.Export_Settings (Runtime.Model, Runtime.Settings, Selected_Path);
            end;
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
      Result :=
        Files.Controller.Handle_Key
          (Model     => Runtime.Model,
           Settings  => Runtime.Settings,
           Key       => To_Key_Code (Key),
           Modifiers => To_Modifiers (As_Window (Runtime.Handle)));
      if Runtime_Should_Resolve_Settings_Path (Result) then
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

   procedure Handle_Mouse
     (Runtime : in out Runtime_Window)
   is
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
      Down     : Boolean;
   begin
      if Runtime.Handle = null then
         return;
      end if;

      Down :=
        Glfw.Windows.Mouse_Button_State (As_Window (Runtime.Handle), Glfw.Input.Mouse.Left_Button) =
        Glfw.Input.Pressed;

      if not Down then
         Runtime.Left_Mouse_Down := False;
         return;
      elsif Runtime.Left_Mouse_Down then
         return;
      end if;

      Runtime.Left_Mouse_Down := True;
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      declare
         X         : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
         Y         : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Snapshot  : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Probe     : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click (Snapshot, X, Y, Natural (Frame_W), Natural (Frame_H));
         Now       : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Modifiers : constant Files.Types.Modifier_Set := To_Modifiers (As_Window (Runtime.Handle));
         Activate  : constant Boolean :=
           Probe.Kind = Files.Events.Item_Click_Input_Action
           and then Probe.Item_Index = Runtime.Last_Click_Item
           and then Now - Runtime.Last_Click_Time <= 0.5;
         Action    : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot, X, Y, Natural (Frame_W), Natural (Frame_H), Activate => Activate, Modifiers => Modifiers);
      begin
         if Probe.Kind = Files.Events.Item_Click_Input_Action then
            Runtime.Last_Click_Item := Probe.Item_Index;
            Runtime.Last_Click_Time := Now;
         else
            Runtime.Last_Click_Item := 0;
         end if;

         Dispatch_Click_Action (Runtime, Action, Modifiers);
      end;
   end Handle_Mouse;

   procedure Handle_All_Mouse
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Handle_Mouse (Runtime);
      end loop;
   end Handle_All_Mouse;

   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Files.Rendering.Vulkan.Shutdown (Runtime.Vulkan);

         if Runtime.Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Runtime.Handle)) then
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
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Scroll);
      Glfw.Windows.Context.Make_Current (As_Window (Handle));
      Glfw.Windows.Context.Set_Swap_Interval (1);
      Glfw.Windows.Show (As_Window (Handle));
      Runtime_Windows.Append
        (Runtime_Window'
           (Handle          => Handle,
            Model           => Startup_Window.Model,
            Settings        => Settings,
            Settings_Path   => Settings_Path,
            Pressed_Keys    => [others => False],
            Left_Mouse_Down => False,
            Last_Click_Item => 0,
            Last_Click_Time => Ada.Calendar.Time_Of (1901, 1, 1),
            Text            => <>,
            Text_Ready      => False,
            Vulkan          => <>,
            Vulkan_Tried    => False,
            Surface_Tried   => False,
            Last_Frame_Width  => 0,
            Last_Frame_Height => 0,
            Fallback_Frames => 0,
            Last_Present_Status => Files.Rendering.Vulkan.Vulkan_Not_Initialized));
   exception
      when others =>
         if Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Handle)) then
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
              Has_Press   => Mouse_Down);
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

         if not Runtime.Text_Ready then
            declare
               Font_Path : constant String := Files.Rendering.Default_Font_Path;
               Status    : constant Files.Rendering.Text_Render_Status :=
                 Files.Rendering.Initialize_Text
                   (Renderer    => Runtime.Text,
                    Font_Path   => Font_Path,
                    Pixel_Size  => 16,
                    Cell_Width  => 10,
                    Cell_Height => 20);
            begin
               Runtime.Text_Ready := Status = Files.Rendering.Text_Render_Success;
            end;
         end if;

         if Runtime.Text_Ready then
            declare
               Glyphs : constant Files.Rendering.Text_Render_Result :=
                 Files.Rendering.Build_Text_Glyphs (Runtime.Text, Frame);
               Batch  : constant Files.Rendering.Vulkan.Submission_Batch :=
                 Files.Rendering.Vulkan.Build_Submission (Frame, Glyphs);
            begin
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
               end if;

               if Runtime.Last_Present_Status /= Files.Rendering.Vulkan.Vulkan_Presented then
                  Runtime.Fallback_Frames := Runtime.Fallback_Frames + 1;
               end if;
            end;
         end if;

         Glfw.Windows.Context.Make_Current (As_Window (Runtime.Handle));
         Glfw.Windows.Context.Swap_Buffers (As_Window (Runtime.Handle));
      end;
   end Render_Window;

   procedure Render_All
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Runtime of Runtime_Windows loop
         Render_Window (Runtime);
      end loop;
   end Render_All;

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
         begin
            if Frame.Layout.Width /= 320
              or else Frame.Layout.Height /= 240
              or else Frame.Rectangles.Is_Empty
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
   begin
      return
        (Display_Available       => Display,
         Vulkan_Available        => Vulkan,
         Native_File_Dialogs     => Native_File_Dialogs_Available,
         Headless_Rendering      => True,
         Live_Window_Smoke_Ready => Display and then Vulkan,
         Event_Translation_Model => True,
         Focus_Runtime_Model     => True,
         Resize_Runtime_Model    => True,
         Scroll_Runtime_Model    => True);
   end Runtime_Capabilities;

   function Runtime_Should_Resolve_Settings_Path
     (Result : Files.Controller.Controller_Result)
      return Boolean is
   begin
      if not Files.Commands.Requires_Settings_Path (Result.Command) then
         return False;
      elsif Result.Status = Files.Controller.Controller_Command_Executed
        and then Result.Operation.Status = Files.Operations.Operation_Disabled
        and then Length (Result.Operation.Error_Key) = 0
      then
         return True;
      end if;

      return Result.Operation.Status = Files.Operations.Operation_Disabled
        and then Result.Status /= Files.Controller.Controller_Command_Executed
        and then To_String (Result.Operation.Error_Key) = "error.dialog.native_unavailable";
   end Runtime_Should_Resolve_Settings_Path;

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

   function Native_File_Dialogs_Available return Boolean is
   begin
      return Files.Platform.Dialogs.Available;
   end Native_File_Dialogs_Available;

   function Native_File_Dialog_Mode_Available
     (Mode : Native_File_Dialog_Mode)
      return Boolean
   is
      Dialog_Profile : constant Files.Platform.Dialogs.Native_Dialog_Profile :=
        Files.Platform.Dialogs.Profile;
   begin
      if Dialog_Profile.Uses_Shell
        or else Dialog_Profile.Binding_Status /= Files.File_System.Native_API_Binding_Available
      then
         return False;
      end if;

      case Mode is
         when Open_File_Dialog =>
            return Dialog_Profile.Can_Open_File;
         when Save_File_Dialog =>
            return Dialog_Profile.Can_Save_File;
      end case;
   end Native_File_Dialog_Mode_Available;

   function Evaluate_Native_File_Dialog
     (Request : Native_File_Dialog_Request)
      return Native_File_Dialog_Result
   is
      Supported : constant Boolean := Native_File_Dialog_Mode_Available (Request.Mode);
   begin
      return
        (Supported     => Supported,
         Attempted     => False,
         Completed     => False,
         Selected_Path => Null_Unbounded_String,
         Backend_Name  => To_Unbounded_String (Files.Platform.Dialogs.Backend_Name),
         Error_Key     =>
           (if Supported then Null_Unbounded_String
            else To_Unbounded_String ("error.dialog.native_unavailable")));
   end Evaluate_Native_File_Dialog;

   function Open_Native_File_Dialog
     (Request : Native_File_Dialog_Request)
      return Native_File_Dialog_Result
   is
      Result : Native_File_Dialog_Result := Evaluate_Native_File_Dialog (Request);
   begin
      if not Result.Supported then
         return Result;
      end if;

      Result.Attempted := True;
      Result.Completed := False;
      Result.Selected_Path := Null_Unbounded_String;
      Result.Error_Key := To_Unbounded_String ("error.dialog.native_unavailable");
      return Result;
   end Open_Native_File_Dialog;

   function Settings_Dialog_Initial_Path
     (Settings_Path : String)
      return String is
   begin
      if Settings_Path = "" then
         return ".";
      end if;

      declare
         Parent : constant String := Ada.Directories.Containing_Directory (Settings_Path);
      begin
         return (if Parent = "" then "." else Parent);
      end;
   exception
      when others =>
         return ".";
   end Settings_Dialog_Initial_Path;

   function Settings_Dialog_Suggested_Name
     (Settings_Path : String)
      return String is
   begin
      if Settings_Path = "" then
         return "files.conf";
      end if;

      declare
         Name : constant String := Ada.Directories.Simple_Name (Settings_Path);
      begin
         return (if Name = "" then "files.conf" else Name);
      end;
   exception
      when others =>
         return "files.conf";
   end Settings_Dialog_Suggested_Name;

   function Settings_Import_Dialog_Request
     (Settings_Path : String)
      return Native_File_Dialog_Request is
   begin
      return
        (Mode               => Open_File_Dialog,
         Title_Key          => To_Unbounded_String ("dialog.settings.import"),
         Initial_Path       => To_Unbounded_String (Settings_Dialog_Initial_Path (Settings_Path)),
         Suggested_Name     => To_Unbounded_String (Settings_Dialog_Suggested_Name (Settings_Path)),
         Required_Extension => To_Unbounded_String ("conf"));
   end Settings_Import_Dialog_Request;

   function Settings_Export_Dialog_Request
     (Settings_Path : String)
      return Native_File_Dialog_Request is
   begin
      return
        (Mode               => Save_File_Dialog,
         Title_Key          => To_Unbounded_String ("dialog.settings.export"),
         Initial_Path       => To_Unbounded_String (Settings_Dialog_Initial_Path (Settings_Path)),
         Suggested_Name     => To_Unbounded_String (Settings_Dialog_Suggested_Name (Settings_Path)),
         Required_Extension => To_Unbounded_String ("conf"));
   end Settings_Export_Dialog_Request;

   function Settings_Path_After_Dialog
     (Configured_Path : String;
      Dialog_Result   : Native_File_Dialog_Result)
      return UString is
   begin
      if Settings_Path_Selected (Dialog_Result) then
         return Dialog_Result.Selected_Path;
      end if;

      return To_Unbounded_String (Configured_Path);
   end Settings_Path_After_Dialog;

   function Normalized_Required_Extension
     (Extension : String)
      return String
   is
      Trimmed : constant String := Ada.Strings.Fixed.Trim (Extension, Ada.Strings.Both);
      First   : Natural := Trimmed'First;
   begin
      while First <= Trimmed'Last and then Trimmed (First) = '.' loop
         First := First + 1;
      end loop;

      if First > Trimmed'Last then
         return "";
      end if;

      return Files.Types.To_Lower (Trimmed (First .. Trimmed'Last));
   end Normalized_Required_Extension;

   function Has_Required_Extension
     (Path      : String;
      Extension : String)
      return Boolean
   is
      Clean_Extension : constant String := Normalized_Required_Extension (Extension);
      Clean_Path      : constant String := Files.Types.To_Lower (Path);
      Suffix          : constant String := "." & Clean_Extension;
   begin
      if Clean_Extension = "" then
         return True;
      elsif Clean_Path'Length < Suffix'Length then
         return False;
      end if;

      return Clean_Path (Clean_Path'Last - Suffix'Length + 1 .. Clean_Path'Last) = Suffix;
   end Has_Required_Extension;

   function Settings_Path_After_Dialog
     (Configured_Path : String;
      Request         : Native_File_Dialog_Request;
      Dialog_Result   : Native_File_Dialog_Result)
      return UString
   is
      Selected_Path : constant UString := Settings_Path_After_Dialog (Configured_Path, Dialog_Result);
      Path_Text     : constant String := To_String (Selected_Path);
      Extension     : constant String := Normalized_Required_Extension (To_String (Request.Required_Extension));
   begin
      if not Settings_Path_Selected (Dialog_Result)
        or else Request.Mode /= Save_File_Dialog
        or else Has_Required_Extension (Path_Text, Extension)
      then
         return Selected_Path;
      end if;

      return To_Unbounded_String (Path_Text & "." & Extension);
   end Settings_Path_After_Dialog;

   function Settings_Path_Selected
     (Dialog_Result : Native_File_Dialog_Result)
      return Boolean is
   begin
      return Dialog_Result.Supported
        and then Dialog_Result.Completed
        and then Length (Dialog_Result.Selected_Path) > 0;
   end Settings_Path_Selected;

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
         Frame_Count      => 1,
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
            Input_Polled       => False,
            Closed_Cleanly     => False,
            Skipped_By_Plan    => True,
            Error_Key          => Plan.Reason_Key);
      end if;

      return
        (Attempted          => False,
         Window_Created     => False,
         Frame_Rendered     => False,
         Input_Polled       => False,
         Closed_Cleanly     => False,
         Skipped_By_Plan    => False,
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
      Glfw.Windows.Hints.Reset_To_Defaults;
      Glfw.Windows.Hints.Set_Resizable (True);
      Glfw.Windows.Hints.Set_Visible (True);

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           => Plan.Width,
            Height          => Plan.Height);
      end loop;

      Result.Window_Created := not Runtime_Windows.Is_Empty;
      for Poll_Index in 1 .. Plan.Input_Poll_Count loop
         Poll_Events;
         Handle_All_Keyboard (Runtime_Windows);
         Handle_All_Text_Input (Runtime_Windows);
         Handle_All_Scroll_Input (Runtime_Windows);
         Handle_All_Mouse (Runtime_Windows);
         Result.Input_Polled := True;
      end loop;

      for Frame_Index in 1 .. Plan.Frame_Count loop
         Render_All (Runtime_Windows);
         Result.Frame_Rendered := True;
      end loop;

      Release_All (Runtime_Windows);
      Glfw.Shutdown;
      Result.Closed_Cleanly := True;
      Result.Error_Key := To_Unbounded_String ("runtime.smoke.ready");
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
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
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
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
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
      Glfw.Windows.Hints.Reset_To_Defaults;
      Glfw.Windows.Hints.Set_Resizable (True);
      Glfw.Windows.Hints.Set_Visible (True);

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           => 1024,
            Height          => 768);
      end loop;

      Render_All (Runtime_Windows);

      while Any_Window_Open (Runtime_Windows) loop
         Glfw.Input.Wait_For_Events;
         Handle_All_Keyboard (Runtime_Windows);
         Handle_All_Text_Input (Runtime_Windows);
         Handle_All_Scroll_Input (Runtime_Windows);
         Handle_All_Mouse (Runtime_Windows);
         Render_All (Runtime_Windows);
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
