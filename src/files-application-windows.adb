with Files.Preview_Decoder;
with Files.Extra_Info_Reader;
with Files.Controller;
with Files.Items;
with Files.Diagnostics;
with Ada.Unchecked_Deallocation;
with System;

with Glfw.Input;
with Glfw.Input.Keys.Codes;
with Glfw.Input.Keys.Layout;
with Glfw.Windows.Modifiers;
with Glfw.Windows.Clipboard;
with Files.Window_Icon;
with Glfw.Windows.Native;
with Glfw.Windows.Vulkan;

with Hostkit.Host;
with Files.File_System;
with Files.Interaction;
with Files.Job_Scavenger;
with Files.Operations;
with Files.Process_Jobs;
with Files.Rendering.Hit;
with Files.UI;
with Guikit.Utf8;

package body Files.Application.Windows is
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Glfw.Input.Button_State;
   use type Glfw.Input.Mouse.Button;
   use type Glfw.Input.Mouse.Coordinate;
   use type Glfw.Size;
   use type Files.Events.Input_Action_Kind;
   use type Files.Commands.Command_Id;
   use type Files.Types.Focus_Target;
   use type Files.Types.Detail_Column;
   use type Files.Types.Item_Kind;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Files.Rendering.View_Snapshot;
   use type System.Address;

   function Key_Repeats (Key : Guikit.Input.Key_Code) return Boolean renames Files.Window_Policy.Key_Repeats;

   --  The text cell width is the advance every layout measures labels with,
   --  taken from the same line height. Derived separately (Size * 3 / 4) it
   --  came out a pixel wider at some sizes, so labels sized to fit lost their
   --  last character and large fonts read "Klei", "Gro", "hom".
   function Cell_Width_For  (Size : Positive) return Positive is
     (Guikit.Layout.Caret_Advance_Width (Cell_Height_For (Size)));

   --  How long a window whose text failed to load waits before trying again.
   Text_Retry_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (5);
   File_Watch_Poll_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   --  With the watch helper reporting changes (Watch_Is_Native), the re-read
   --  only covers what it can miss (a change made over the network to a
   --  mounted folder).
   --  Each re-read stats every entry, so in a large folder it is not free.
   Native_Watch_Poll_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (10);
   Type_Ahead_Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (1);
   --  The event loop always waits this long: input, window refresh, and posted
   --  events wake it immediately, and this bounds how long a background file
   --  change (native watch / interval poll) or an animation frame waits. Present
   --  is skipped for unchanged frames, so a short wait keeps input responsive
   --  without the idle cost of actually re-rendering. (An earlier adaptive
   --  long-idle wait cut idle CPU only ~2% -> ~1% but let input lag up to a
   --  second, so it was dropped.)
   Event_Wait_Timeout : constant Duration := 0.016;

   --  The wait while a background paste runs (see Event_Loop_Wait).
   Paste_Wait_Timeout : constant Duration := 0.001;

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

   --  Two clicks on the same item at most this far apart activate it.
   Double_Click_Interval : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (500);

   procedure Free_Window is new Ada.Unchecked_Deallocation
     (Object => Desktop_Window,
      Name   => Window_Access);

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
         Runtime.Font_Pixel_Size := Scaled_Font_Size (Runtime);
      end if;
      if Result.Needs_Glyph_Rebuild then
         Runtime.Text_Ready := False;
         Runtime.Glyph_Text_Valid := False;
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

      Glfw.Windows.Clipboard.Set
        (As_Window (Runtime.Handle), Files.Model.System_Clipboard_Request_Text (Runtime.Model));

      Files.Model.Clear_System_Clipboard_Request (Runtime.Model);
   end Flush_System_Clipboard;

   overriding procedure Receive
     (Into    : in out Desktop_Window;
      Dropped : Glfw.Windows.Drop.Paths.Path_Vectors.Vector)
   is
      Drops : Files.Types.String_Vectors.Vector;
   begin
      for Path of Dropped loop
         Drops.Append (To_Unbounded_String (Path));
      end loop;
      Files.Drop_Events.Queue (Into.Drop_Source, Drops);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Receive;

   --  A drop guikit could not hand over (FILES_DIAGNOSTICS); it is lost.
   overriding procedure Failed
     (Into       : in out Desktop_Window;
      Occurrence : Ada.Exceptions.Exception_Occurrence)
   is
      pragma Unreferenced (Into);
   begin
      Files.Diagnostics.Note_Event_Loop (Occurrence);
   end Failed;

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
      Dropped  : constant Boolean := Object.Drop_Next_Character;
   begin
      Object.Last_Was_Tracked_Press := False;
      Object.Drop_Next_Character := False;
      if Bytes = "" or else Dropped then
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

   --  The key a press means under the keyboard layout (QWERTZ: Ctrl+Z).
   function Layout_Key
     (Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode)
      return Glfw.Input.Keys.Key renames Glfw.Input.Keys.Layout.Layout_Key;

   overriding procedure Key_Changed
     (Object   : not null access Desktop_Window;
      Key      : Glfw.Input.Keys.Key;
      Scancode : Glfw.Input.Keys.Scancode;
      Action   : Glfw.Input.Keys.Action;
      Mods     : Glfw.Input.Keys.Modifiers)
   is
      use type Glfw.Input.Keys.Action;
      use type Guikit.Input.Key_Code;
   begin
      Object.Last_Was_Tracked_Press := False;
      Object.Drop_Next_Character := False;
      if Action = Glfw.Input.Keys.Release then
         return;
      end if;
      declare
         Code : constant Guikit.Input.Key_Code := Glfw.Input.Keys.Codes.To_Key_Code (Layout_Key (Key, Scancode));
      begin
         if Code = Guikit.Input.Key_Unknown then
            return;
         --  A held key repeats as the system's own repeat settings say: the
         --  window system sends Repeat for it.
         elsif Action = Glfw.Input.Keys.Repeat and then not Key_Repeats (Code) then
            Object.Drop_Next_Character := True;
         elsif Natural (Object.Pending_Input.Length) < Max_Pending_Input_Events then
            Object.Pending_Input.Append
              (Input_Event'
                 (Kind      => Key_Press_Event,
                  Key       => Code,
                  Modifiers => Glfw.Input.Keys.Codes.To_Modifiers (Mods),
                  others    => <>));
            Object.Last_Was_Tracked_Press := True;
         end if;
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
      use type Files.Mouse_Buttons.Button_Kind;
      Event   : Files.Mouse_Buttons.Button_Event :=
        (Button    => Files.Mouse_Buttons.Left_Mouse_Button,
         Pressed   => State = Glfw.Input.Pressed,
         X         => Object.Last_Mouse_X,
         Y         => Object.Last_Mouse_Y,
         Modifiers => Glfw.Input.Keys.Codes.To_Modifiers (Mods),
         Dragged   => False,
         At_Time   => Ada.Real_Time.Clock);
      Bounced : Boolean;
   begin
      if Button = Glfw.Input.Mouse.Right_Button then
         --  A right-click acts on the press, where it went down.
         if State /= Glfw.Input.Pressed then
            return;
         end if;
         Event.Button := Files.Mouse_Buttons.Right_Mouse_Button;
      elsif Button /= Glfw.Input.Mouse.Left_Button then
         return;
      elsif not Event.Pressed then
         Event.Dragged := Object.Drag_Moved;
      end if;

      Files.Mouse_Buttons.Queue_Event
        (Object.Pending_Mouse, Object.Last_Left_Press_Time, Event, Bounced);
      if Event.Button /= Files.Mouse_Buttons.Left_Mouse_Button then
         return;
      elsif not Event.Pressed then
         Object.Left_Mouse_Down := False;
      elsif Bounced then
         --  The button is physically down again after the bounce's release.
         Object.Left_Mouse_Down := True;
      else
         Object.Left_Mouse_Down := True;
         Object.Drag_Start_X := Event.X;
         Object.Drag_Start_Y := Event.Y;
         Object.Drag_Moved := False;
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
      return Guikit.Input.Modifier_Set renames Glfw.Windows.Modifiers.Held;

   --  @return Minutes since 2000-01-01 by the wall clock: the key that tells
   --    a snapshot or frame built in an earlier minute (relative times) apart.
   function Wall_Clock_Minute return Natural is separate;

   --  Make Runtime.View.Snapshots (Runtime.View.Current_Slot) the snapshot of the model
   --  and settings as they are now, rebuilding it only when the model revision,
   --  the snapshot settings or the minute moved since it was built (or a paste
   --  is running, whose progress no revision tracks: then at most ten times a
   --  second). This is the render's own validity check, so a handler that
   --  lays the view out between frames shares the snapshot the next render
   --  draws instead of rebuilding it per event. A rebuild never overwrites the drawn snapshot (Drawn_Slot).
   --  Callers rename the slot after calling, and call again after mutating the
   --  model before they lay it out again.
   --
   --  @param Runtime Window whose current snapshot is brought up to date.
   procedure Refresh_Snapshot (Runtime : in out Runtime_Window) is
   begin
      Files.Snapshot_Slots.Refresh (Runtime.View, Runtime.Model, Runtime.Settings, Ada.Real_Time.Clock);
   end Refresh_Snapshot;

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
            Files.Model.Set_Selection_Page_Rows
              (Runtime.Model,
               Files.Rendering.Main_View_Page_Rows (Snapshot, Layout, Cell_Height_For (Runtime.Font_Pixel_Size)));
         end Apply;
      begin
         --  Runs before every key fire, auto-repeat included; the current
         --  snapshot is rebuilt only when the model or settings moved.
         Refresh_Snapshot (Runtime);
         Apply (Runtime.View.Snapshots (Runtime.View.Current_Slot));
      end;
   end Refresh_Selection_Grid_Columns;

   --  Dispatch one tracked key press.
   --
   --  @param Runtime Window receiving the key.
   --  @param Key The key, already resolved through the keyboard layout.
   --  @param Modifiers Modifiers held with the key.
   --  @param Consumed True when the key's own character must be dropped.
   procedure Fire_Key
     (Runtime   : in out Runtime_Window;
      Key       : Guikit.Input.Key_Code;
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
         Runtime.Type_Ahead_Input_At := Ada.Real_Time.Clock;
      end if;

      Result := Files.Controller.Append_Focused_Text (Runtime.Model, Text);
      pragma Unreferenced (Result);
   end Dispatch_Text;

   --  Scroll the main view just far enough that the selected item is whole
   --  in view, after a key or type-ahead moved the selection.
   procedure Reveal_Selection (Runtime : in out Runtime_Window) is
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Selected : constant Natural := Files.Model.Selected_Index (Runtime.Model);
   begin
      if Runtime.Handle = null or else Selected = 0 then
         return;
      end if;
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Refresh_Snapshot (Runtime);
      declare
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Snapshot    : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Current_Slot);
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Lines       : constant Natural :=
           Files.Rendering.Scroll_Lines_Revealing (Snapshot, Layout, Line_Height, Positive (Selected));
      begin
         if Lines /= Files.Model.Main_View_Scroll_Lines (Runtime.Model) then
            Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, Lines);
         end if;
      end;
   end Reveal_Selection;

   --  Run the window's key presses and typed text in the order they arrived.
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window)
   is
      Events   : Input_Event_Vectors.Vector;
      Consumed : Boolean := False;
      Selected_Before : Natural := 0;
      Path_Before     : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      --  This runs on every pass of the loop; with no key event nothing
      --  below can happen, and Selected_Index walks the items.
      if Runtime.Handle.Pending_Input.Is_Empty then
         return;
      end if;
      Selected_Before := Files.Model.Selected_Index (Runtime.Model);
      Path_Before := To_Unbounded_String (Files.Model.Current_Path (Runtime.Model));
      Events := Runtime.Handle.Pending_Input;
      Runtime.Handle.Pending_Input.Clear;
      Runtime.Handle.Last_Was_Tracked_Press := False;
      Runtime.Handle.Drop_Next_Character := False;

      for Event of Events loop
         case Event.Kind is
            when Key_Press_Event =>
               --  With the trace below a presented frame, CI follows a key
               --  it sends through the loop onto the screen.
               Files.Diagnostics.Trace ("Files.Application.Windows", "key=" & Guikit.Input.Key_Code'Image (Event.Key));
               Fire_Key (Runtime, Event.Key, Event.Modifiers, Consumed);
            when Text_Event =>
               if not (Event.Parallel and then Consumed) then
                  Dispatch_Text (Runtime, To_String (Event.Text));
               end if;
               Consumed := False;
         end case;
      end loop;

      --  The selection follows the keyboard into view.
      if Runtime.Handle /= null
        and then (Files.Model.Selected_Index (Runtime.Model) /= Selected_Before
                  or else Files.Model.Current_Path (Runtime.Model) /= To_String (Path_Before))
      then
         Reveal_Selection (Runtime);
      end if;
   end Handle_Keyboard;

   --  Run one per-window step for every window, each behind its own exception
   --  boundary. A step that fails for one window's state must not starve the
   --  others of input, rendering, file watching or folder sizes, which a single
   --  handler around the whole loop pass did. The failing window's frame cache
   --  is dropped so its next frame is rebuilt rather than left stale.
   --  Every window writes its whole settings model to the one shared file, so
   --  each must see the others' changes: otherwise closing (or zooming) a
   --  window with a stale copy silently reverts a theme, favourite or label
   --  changed in another. A window whose settings moved since the last sync
   --  (its settings revision differs from the one synced) hands them to every
   --  other window; the revision makes that check a number comparison, not a
   --  walk over every map and list in the settings; a lone window only
   --  catches up its mark. For_Each_Window shares after every window's step,
   --  so two windows can never both have unshared changes (which would leave
   --  only one of them to win).
   --  Each other window adopts them (Interaction.Adopt_Shared_Settings): an
   --  open settings pane there is refreshed, a listing whose options or type
   --  mappings changed is reloaded.
   procedure Share_Settings_From
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Index           : Positive)
   is separate;

   procedure Sync_Settings_Across_Windows
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      for Index in Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         Share_Settings_From (Runtime_Windows, Index);
      end loop;
   end Sync_Settings_Across_Windows;

   procedure For_Each_Window
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Step            : not null access procedure (Runtime : in out Runtime_Window)) is
   begin
      for Index in Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         declare
            Runtime : Runtime_Window renames Runtime_Windows (Index);
         begin
            --  Keep the items in the drawn group order before any step reads
            --  or walks them; a no-op unless the model or grouping changed.
            Files.Model.Sync_Grouping (Runtime.Model, Runtime.Settings);
            Step (Runtime);
         exception
            --  One window's step failing must not stop the others; it is
            --  rebuilt next pass. Recorded (FILES_DIAGNOSTICS): a step that
            --  fails every pass leaves that window undrawn.
            when Swallowed : others =>
               Files.Diagnostics.Note_Event_Loop (Swallowed);
               Runtime.Frame_Cache_Valid := False;
               Runtime.View.Snapshot_Valid := False;
         end;
         Share_Settings_From (Runtime_Windows, Index);
      end loop;
   end For_Each_Window;

   procedure Handle_All_Keyboard
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Keyboard'Access);
   end Handle_All_Keyboard;

   --  Clear a stale grid type-ahead prefix once the user has paused, on the
   --  event loop's monotonic clock, so a keystroke after it starts afresh.
   procedure Handle_Type_Ahead_Timeout
     (Runtime : in out Runtime_Window) is
   begin
      if Files.Model.Type_Ahead_Buffer (Runtime.Model) /= ""
        and then Ada.Real_Time.Clock > Runtime.Type_Ahead_Input_At + Type_Ahead_Timeout
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
      Files.Operations.Cancel_Folder_Scan (Model);
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
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Result : Files.Operations.Operation_Result;
      pragma Unreferenced (Result);
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
      --  The selected item's type details, read off the UI thread; this also
      --  serves selections deferred by a cancelled or failed refresh.
      Files.Operations.Poll_Selected_Item_Extra
        (Runtime.Model, Files.Extra_Info_Reader.Requester (Runtime.A11y_Key), Runtime.Settings.Show_Hidden_Files);

      declare
         Changed     : constant Boolean := Drain_Native_Watch (Runtime);
         Load_Failed : constant Boolean :=
           Files.Model.Last_Error_Key (Runtime.Model) = "error.directory.load";
         Polled      : Boolean;
      begin
         --  A burst of writes is paced to one reload per gap, the last one
         --  owed and paid; a listing that cannot be read is retried slowly.
         case Files.Refresh_Jobs.Watch_Step
           (Pacer       => Runtime.Watch_Pacing,
            Now         => Now,
            Changed     => Changed,
            Read_Active => Files.Process_Jobs.Active (Files.Model.Background_Refresh (Runtime.Model)),
            Load_Failed => Load_Failed,
            Poll_Due    =>
              Now >= Runtime.Last_Watch_Poll + File_Watch_Poll_Interval
              and then (not Files.Refresh_Jobs.Watch_Is_Native (Runtime.Watch)
                        or else Now >= Runtime.Last_Watch_Poll + Native_Watch_Poll_Interval),
            Polled      => Polled)
         is
            when Files.Refresh_Jobs.Watch_Refresh =>
               Result := Files.Operations.Refresh_If_Changed (Runtime.Model, Runtime.Settings);
            when Files.Refresh_Jobs.Watch_Wait =>
               null;
         end case;
         if Polled then
            Runtime.Last_Watch_Poll := Now;
         end if;
      end;
   end Handle_File_Watch_Poll;

   procedure Handle_All_File_Watch_Poll
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_File_Watch_Poll'Access);
   end Handle_All_File_Watch_Poll;

   --  How long the event loop may wait for input: Paste_Wait_Timeout while
   --  any window carries out a paste through a helper process, else
   --  Event_Wait_Timeout, cut short to when a held-back mouse release
   --  (Files.Mouse_Buttons.Ready_At) may be handled.
   function Event_Loop_Wait (Runtime_Windows : Runtime_Window_Vectors.Vector) return Duration is separate;

   --  Each window polls its own background work -- folder measurements and
   --  the Quick Look decode -- and publishes only its own results.
   procedure Poll_Window_Workers (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
      procedure Poll (Runtime : in out Runtime_Window) is
      begin
         if Runtime.Handle /= null then
            declare
               Busy : constant Boolean :=
                 Files.Model.Paste_Execution_Is_Active (Runtime.Model)
                 or else Files.Process_Jobs.Active (Files.Model.Background_Refresh (Runtime.Model));
            begin
               --  Only the items and the selection decide what is measured: a
               --  measurement arriving (which moves Revision) asks for nothing.
               if Files.Model.Rows_Revision (Runtime.Model) /= Runtime.Folder_Size_Rows
                 or else Files.Model.Selection_Revision (Runtime.Model) /= Runtime.Folder_Size_Selection
                 or else Busy /= Runtime.Folder_Size_Busy
               then
                  Files.Operations.Update_Folder_Size (Runtime.Model, Runtime.Settings);
                  Runtime.Folder_Size_Rows := Files.Model.Rows_Revision (Runtime.Model);
                  Runtime.Folder_Size_Selection := Files.Model.Selection_Revision (Runtime.Model);
                  Runtime.Folder_Size_Busy := Busy;
               end if;
            end;
            Files.Operations.Poll_Folder_Sizes (Runtime.Model);
            Files.Operations.Poll_Quick_Look
              (Runtime.Model, Files.Preview_Decoder.Requester (Runtime.A11y_Key));
         end if;
      end Poll;
   begin
      For_Each_Window (Runtime_Windows, Poll'Access);
   end Poll_Window_Workers;

   procedure Save_Pending_Zoom (Runtime : in out Runtime_Window; Force : Boolean) is separate;
   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
 is separate;

   procedure Handle_All_Scroll_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Scroll_Input'Access);
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
            --  The pixel the point lies in: truncate, as the framebuffer's
            --  pixel grid does. A conversion would round, putting the right
            --  half of every pixel in the next one.
            return Natural (Long_Float'Floor (Scaled));
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
      --  resize is applied per frame by Update_Column_Resize_Drag.
      if Action.Kind = Files.Events.Column_Resize_Begin_Input_Action then
         Runtime.Column_Resize.Active := True;
         Runtime.Column_Resize.Changed := False;
         Runtime.Column_Resize.Target := Action.Column;
         Runtime.Column_Resize.Origin_X := Action.Origin_X;
         Runtime.Column_Resize.Origin_W := Action.Column_Width;
         return;
      end if;

      --  Column-reorder begin arms shell-owned drag state; the drop (or the
      --  sort fallback for a press without a drag) is applied per frame by
      --  Update_Column_Reorder_Drag.
      if Action.Kind = Files.Events.Column_Reorder_Begin_Input_Action then
         Runtime.Column_Reorder.Active := True;
         Runtime.Column_Reorder.Target := Action.Column;
         Runtime.Column_Reorder.Origin_X := Action.Origin_X;
         Runtime.Column_Reorder.Started := False;
         Runtime.Column_Reorder.Sort := Action.Sort_Command;
         return;
      end if;

      --  Marquee begin arms shell-owned rubber-band state; the continuous
      --  selection is applied per frame by Update_Marquee_Drag. The prior selection is snapshotted now so an
      --  additive drag can union against it without the per-frame reapply
      --  erasing it.
      if Action.Kind = Files.Events.Marquee_Begin_Input_Action then
         Runtime.Marquee.Active := True;
         Runtime.Marquee.Moved := False;
         Runtime.Marquee.Last_X := Integer'First;
         Runtime.Marquee.Origin_X := Action.Origin_X;
         Runtime.Marquee.Origin_Y := Action.Origin_Y;
         Runtime.Marquee.Additive := Action.Additive;
         Runtime.Marquee.Base := Files.Interaction.Selected_Visible_Indices (Runtime.Model);
         Runtime.Marquee.Rect_X := 0;
         Runtime.Marquee.Rect_Y := 0;
         Runtime.Marquee.Rect_W := 0;
         Runtime.Marquee.Rect_H := 0;
         return;
      end if;

      Files.Interaction.Apply_Input_Action
        (Model             => Runtime.Model,
         Settings          => Runtime.Settings,
         Settings_Path     => To_String (Runtime.Settings_Path),
         Action            => Action,
         Modifiers         => Modifiers,
         Result            => Result);
      Apply_Interaction_Result (Runtime, Result);
   end Dispatch_Click_Action;

   --  The snapshot to hit-test pointer input against: the one the frame on
   --  screen was built from, not the model as a refresh since may have
   --  changed it, so a clicked index names the item drawn under the pointer.
   --  Before the first frame there is nothing drawn; the model is used as is.
   function Hit_Slot (Runtime : in out Runtime_Window) return Snapshot_Slot is
   begin
      if not Runtime.Frame_Cache_Valid then
         Refresh_Snapshot (Runtime);
         return Runtime.View.Current_Slot;
      end if;
      return Runtime.View.Drawn_Slot;
   end Hit_Slot;

   --  The model's visible index of the item drawn at Index in Slot. The
   --  frame on screen can be older than the rows (a watched change, a key
   --  that navigated or sorted): an index into it then names a different item, so the
   --  drawn item is found again (Item_Now), and a click on one that is gone
   --  lands nowhere (0).
   function Current_Item_Index
     (Runtime : Runtime_Window;
      Slot    : Snapshot_Slot;
      Index   : Natural)
      return Natural is
   begin
      if Index = 0 or else Runtime.View.Slot_Model_Rows (Slot) = Files.Model.Rows_Revision (Runtime.Model) then
         return Index;
      end if;
      return Files.Rendering.Item_Now (Runtime.View.Snapshots (Slot), Index, Runtime.Model);
   end Current_Item_Index;

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
         return (Kind => Files.Events.No_Input_Action);
      end if;

      declare
         X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
         Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
         Slot     : constant Snapshot_Slot := Hit_Slot (Runtime);
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Slot);
         Action   : Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snapshot    => Snapshot,
              Frame       => Runtime.Cached_Frame,
              X           => X,
              Y           => Y,
              Width       => Natural (Frame_W),
              Height      => Natural (Frame_H),
              Modifiers   => Modifiers,
              Line_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
      begin
         if Action.Kind = Files.Events.Item_Click_Input_Action then
            Action.Item_Index := Current_Item_Index (Runtime, Slot, Action.Item_Index);
            if Action.Item_Index = 0 then
               return (Kind => Files.Events.No_Input_Action);
            end if;
         end if;
         return Action;
      end;
   end Current_Click_Action;

   --  Carry out what the screen reader asked, as a click on the node's centre
   --  would: "focus" selects it, "activate" also opens an item (as a double
   --  click does) or presses a button.
   procedure Perform_Accessibility_Request
     (Runtime : in out Runtime_Window;
      Item    : A11ykit.Provider.Request)
   is separate;

   function Selected_File_Paths
     (Model : Files.Model.Window_Model)
      return Files.Types.String_Vectors.Vector
   is
      Items  : constant Files.Items.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
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
         Target : constant Files.Items.Directory_Item :=
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

   procedure Release_Window (Runtime : in out Runtime_Window) is separate;

   procedure Release_Closed_Windows (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      --  A released window leaves the vector, so its model (listing,
      --  thumbnails, history) is freed instead of kept until exit. Nothing
      --  holds a window by index across passes of the loop.
      for Index in reverse Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         declare
            Released : Boolean;
         begin
            --  The reference must end before Delete, which tampers.
            declare
               Runtime : Runtime_Window renames Runtime_Windows (Index);
            begin
               if Runtime.Handle /= null
                 and then (not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
                           or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle)))
               then
                  Release_Window (Runtime);
               end if;
               Released := Runtime.Handle = null;
            end;
            if Released then
               Runtime_Windows.Delete (Index);
            end if;
         end;
      end loop;
   end Release_Closed_Windows;

   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      --  Each window's scan ends with the window (Release_Window).
      for Runtime of Runtime_Windows loop
         Release_Window (Runtime);
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
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Key);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Button);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Position);
      Glfw.Windows.Enable_Callback (As_Window (Handle), Glfw.Windows.Callbacks.Mouse_Scroll);
      Files.Window_Icon.Set (As_Window (Handle));
      --  One more than a drop may hold, so an oversized one can be refused.
      Glfw.Windows.Drop.Paths.Watch (As_Window (Handle), Handle, Limit => Files.Drop_Events.Max_Paths + 1);
      Glfw.Windows.Show (As_Window (Handle));
      Runtime_Windows.Append
        (Runtime_Window'
           (Handle          => Handle,
            A11y_Key        => Files.Accessibility.New_Window_Key,
            Model           => Startup_Window.Model,
            Settings        => Settings,
            Synced_Settings_Revision => Files.Model.Settings_Revision (Startup_Window.Model),
            Settings_Path   => Settings_Path,
            Font_Pixel_Size => Settings.Font_Pixel_Size,
            Shown           => True,
            others          => <>));
      Files.Model.Set_Background_Transfers
        (Runtime_Windows.Reference (Runtime_Windows.Last_Index).Model, True);
      --  The screen reader looks at the window itself; answer it there.
      Files.Accessibility.Attach_Window
        (Runtime_Windows.Reference (Runtime_Windows.Last_Index).A11y_Key,
         Glfw.Windows.Native.Handle (As_Window (Handle)));
   exception
      when others =>
         if Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Handle)) then
               Glfw.Windows.Drop.Paths.Forget (As_Window (Handle));
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

   --  End a column-resize drag. Its moves resized the column in memory only;
   --  the settings file is written once, here.
   procedure End_Column_Resize_Drag (Runtime : in out Runtime_Window) is
   begin
      if Runtime.Column_Resize.Active then
         Files.Interaction.End_Column_Resize
           (Model         => Runtime.Model,
            Settings      => Runtime.Settings,
            Settings_Path => To_String (Runtime.Settings_Path),
            Changed       => Runtime.Column_Resize.Changed);
      end if;
      Runtime.Column_Resize.Active := False;
      Runtime.Column_Resize.Changed := False;
   end End_Column_Resize_Drag;

   procedure Update_Column_Resize_Drag
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Mouse_Down : Boolean)
   is
      Result : Files.Interaction.Interaction_Result;
   begin
      if not Runtime.Column_Resize.Active then
         return;
      elsif not Mouse_Down or else Window_W = 0 or else Frame_W = 0 then
         End_Column_Resize_Drag (Runtime);
         return;
      end if;

      Files.Interaction.Apply_Column_Resize
        (Model        => Runtime.Model,
         Settings     => Runtime.Settings,
         Column       => Runtime.Column_Resize.Target,
         Origin_X     => Runtime.Column_Resize.Origin_X,
         Origin_Width => Runtime.Column_Resize.Origin_W,
         Current_X    => Scale_Coordinate (Cursor_X, Window_W, Frame_W),
         Result       => Result,
         Line_Height  => Cell_Height_For (Runtime.Font_Pixel_Size));
      if Result.Settings_Changed then
         Runtime.Column_Resize.Changed := True;
      end if;
   end Update_Column_Resize_Drag;

   --  Minimum pointer travel, in frame pixels at the reference line height
   --  (scaled with the text), before an armed header press becomes a reorder
   --  drag. Below it a press/release is treated as a sort click, matching the
   --  resize hot zone's grabbable-yet-forgiving feel.
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
   is separate;

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
        and then not Files.Model.Other_Input_Owning_Overlay_Is_Open (Runtime.Model, Files.Model.Tree_Pick_Overlay);
   begin
      if not Files.Model.Input_Owning_Overlay_Is_Open (Runtime.Model) then
         return;
      end if;

      Runtime.Drag_Source_Index := 0;
      if not Keep_Tree_Scrollbar then
         Runtime.Scrollbar_Drag_Target := Files.Events.Scroll_Auto;
         Runtime.Scrollbar_Drag_Anchor := 0;
      end if;
      End_Column_Resize_Drag (Runtime);
      Runtime.Column_Reorder.Active := False;
      Runtime.Column_Reorder.Started := False;
      Runtime.Column_Reorder.Sort := Files.Commands.No_Command;
      Runtime.Marquee.Active := False;
      Runtime.Marquee.Moved := False;
      Runtime.Marquee.Base.Clear;
      Runtime.Marquee.Rect_X := 0;
      Runtime.Marquee.Rect_Y := 0;
      Runtime.Marquee.Rect_W := 0;
      Runtime.Marquee.Rect_H := 0;
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

   function Live_Display_Available return Boolean renames Hostkit.Host.Has_Window_Server;

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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Application.Windows");
         if Initialized then
            Glfw.Shutdown;
         end if;
         return False;
   end Vulkan_Runtime_Available;

   function Runtime_Capabilities return Desktop_Capabilities is
     (Capabilities_Of (Live_Display_Available, Vulkan_Runtime_Available));

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

   procedure Event_Loop_Pass
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      State           : in out Event_Loop_State) is
   begin
      Files.Accessibility.Service;
      declare
         use type Files.Accessibility.Window_Key;
         Request : A11ykit.Provider.Request;
         Window  : Files.Accessibility.Window_Key;
      begin
         while Files.Accessibility.Next_Request (Window, Request) loop
            for Runtime of Runtime_Windows loop
               if Runtime.A11y_Key = Window then
                  Perform_Accessibility_Request (Runtime, Request);
               end if;
            end loop;
         end loop;
      end;
      declare
         Focused : Files.Accessibility.Window_Key := 0;
      begin
         for Runtime of Runtime_Windows loop
            if Runtime.Handle /= null and then Glfw.Windows.Focused (As_Window (Runtime.Handle)) then
               Focused := Runtime.A11y_Key;
            end if;
         end loop;
         Files.Accessibility.Set_Active (Focused);
      end;
      Handle_All_Keyboard (Runtime_Windows);
      Handle_All_Type_Ahead_Timeout (Runtime_Windows);
      Handle_All_Mouse (Runtime_Windows);
      Handle_All_Drop_Input (Runtime_Windows);
      Handle_All_Scroll_Input (Runtime_Windows);
      Sync_Settings_Across_Windows (Runtime_Windows);
      --  A report file appears rarely: looked for once a second, not on
      --  every wake-up.
      if not State.Recovery_Reported and then Ada.Real_Time.Clock >= State.Next_Recovery_Check then
         State.Next_Recovery_Check := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (1);
         if Files.Job_Scavenger.Has_Unrecoverable then
            for Runtime of Runtime_Windows loop
               if Runtime.Handle /= null then
                  Files.Model.Set_Error
                    (Runtime.Model, "error.recovery.unsafe_transport");
                  Runtime.Frame_Cache_Valid := False;
                  Runtime.View.Snapshot_Valid := False;
               end if;
            end loop;
            State.Recovery_Reported := True;
         end if;
      end if;
      Render_All (Runtime_Windows);
      Handle_All_File_Watch_Poll (Runtime_Windows);
      Poll_Window_Workers (Runtime_Windows);
   exception
      --  Resilience: a stray error while handling one frame's input or
      --  rendering should not tear down every window. Skip the frame and
      --  keep the event loop running. (The caller's wait paces the loop, so
      --  this cannot become a tight busy-spin.)
      when Swallowed : others =>
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Event_Loop_Pass;

   procedure Run
     (Startup : Files.Application.Startup_Result)
   is
      Runtime_Windows : Runtime_Window_Vectors.Vector;
      Initialized     : Boolean := False;
      State           : Event_Loop_State;
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
               else Files.UI.Default_Window_Width),
            Height          =>
              (if Startup.Settings.Window_Height > 0
               then Startup.Settings.Window_Height
               else Files.UI.Default_Window_Height));
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
         --  A background paste starts its next item only on a loop pass:
         --  waiting out the full timeout after each made a paste of many
         --  small files take minutes. While one runs, look again at once.
         Guikit.Vulkan.Wait_For_Events (Event_Loop_Wait (Runtime_Windows));
         Release_Closed_Windows (Runtime_Windows);
         exit when not Any_Window_Open (Runtime_Windows);
         Event_Loop_Pass (Runtime_Windows, State);
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
