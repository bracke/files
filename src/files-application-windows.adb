with Files.Model.Jobs;
with Files.Events;
with Files.UI_Types;
with Files.Operation_Results;
with Ada.Calendar;
with Ada.Containers;
with Files.Application.Window_Polls;
with Files.Job_Drivers.Foreground;
with Files.Application.Preview_Decoder;
with Files.Application.Extra_Info_Reader;
with Files.Application.Tree_Reader;
with Files.Controller;
with Files.Diagnostics;
with Ada.Unchecked_Deallocation;

with Glfw.Input;
with Glfw.Input.Keys.Codes;
with Glfw.Input.Keys.Layout;
with Glfw.Windows.Modifiers;
with Glfw.Windows.Clipboard;
with Files.Application.Window_Icon;
with Glfw.Windows.Content_Scale;
with Glfw.Windows.Native;
with Glfw.Windows.Vulkan;

with Hostkit.Host;
with Files.Interaction;
with Files.Jobs.Scavenger;
with Files.Operations;
with Files.Model.Clipboard;
with Files.Model.Tree_Panel;
with Files.Model.Settings_Pane;
with Files.Model.Selection;
with Files.Rendering.Layouts;
with Files.Application.Windows.Gestures;
with Files.Application.Windows.Watch;
with Files.Text_Basics;

package body Files.Application.Windows is
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Glfw.Input.Button_State;
   use type Glfw.Input.Mouse.Button;
   use type Glfw.Input.Mouse.Coordinate;
   use type Glfw.Size;
   use type Files.Input_Actions.Input_Action_Kind;
   use type Files.UI_Types.Focus_Target;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Files.Rendering.View_Snapshot;

   function Key_Repeats (Key : Guikit.Input.Key_Code) return Boolean
     renames Files.Application.Window_Policy.Key_Repeats;

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

   --  Two clicks on the same item at most this far apart activate it: the
   --  interval every guikit application shares.
   Double_Click_Interval : Ada.Real_Time.Time_Span renames Guikit.Input.Mouse_Buttons.Double_Click_Interval;

   procedure Free_Window is new Ada.Unchecked_Deallocation
     (Object => Desktop_Window,
      Name   => Window_Access);

   function As_Window
     (Handle : Window_Access)
      return Glfw.Windows.Window_Reference is
   begin
      return Glfw.Windows.Window_Reference (Handle);
   end As_Window;

   --  Writes any pending system-clipboard request the model recorded (for
   --  example from the Copy Path command) to the GLFW system clipboard, then
   --  clears it. A no-op when no request is pending.
   procedure Flush_System_Clipboard (Runtime : in out Runtime_Window) is
   begin
      if Runtime.Handle = null
        or else not Files.Model.Clipboard.System_Request_Pending (Runtime.Model)
      then
         return;
      end if;

      Glfw.Windows.Clipboard.Set
        (As_Window (Runtime.Handle), Files.Model.Clipboard.System_Request_Text (Runtime.Model));

      Files.Model.Clipboard.Clear_System_Request (Runtime.Model);
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

   overriding procedure Character_Entered
     (Object : not null access Desktop_Window;
      Char   : Wide_Wide_Character) is separate;

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
      Mods     : Glfw.Input.Keys.Modifiers) is separate;

   overriding procedure Mouse_Scrolled
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Scroll_Offset;
      Y      : Glfw.Input.Mouse.Scroll_Offset) is separate;

   overriding procedure Mouse_Button_Changed
     (Object : not null access Desktop_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers) is separate;

   overriding procedure Mouse_Position_Changed
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate) is separate;

   function To_Modifiers
     (Window : not null access Glfw.Windows.Window)
      return Guikit.Input.Modifier_Set renames Glfw.Windows.Modifiers.Held;

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
      --  A step that replaced the items (a navigation, a reload) and then
      --  reveals or lays out in that same step must see them in group order:
      --  For_Each_Window only regroups before each step. A no-op when banded.
      Files.Model.Sync_Grouping (Runtime.Model, Runtime.Settings);
      Files.Application.Snapshot_Slots.Refresh
        (Runtime.View, Runtime.Model, Runtime.Settings, Ada.Real_Time.Clock, Ada.Calendar.Clock);
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
              Files.Rendering.Layouts.Calculate_Layout
                (Snapshot, Natural (Frame_W), Natural (Frame_H),
                 Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size));
            Main_View : constant Files.Rendering.Layouts.Main_View_Layout :=
              Files.Rendering.Layouts.Calculate_Main_View_Layout
                (Snapshot, Layout, Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size));
         begin
            Files.Model.Selection.Set_Grid_Columns (Runtime.Model, Main_View.Columns);
            Files.Model.Selection.Set_Page_Rows
              (Runtime.Model,
               Files.Rendering.Layouts.Main_View_Page_Rows
                 (Snapshot, Layout, Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size)));
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
      Result : Files.Interaction.Interaction_Result;
   begin
      --  When the grid owns the keyboard this run feeds type-ahead; stamp the
      --  activity time so the inactivity timeout below measures from the last
      --  keystroke rather than from the previous field edit.
      if Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_None then
         Runtime.Type_Ahead_Input_At := Ada.Real_Time.Clock;
      end if;

      --  The edit or type-ahead move is in the model, which the next frame
      --  draws: a character leaves the window nothing to follow up.
      Files.Interaction.Append_Text
        (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path), Text, Result);
   end Dispatch_Text;

   --  Scroll the main view just far enough that the selected item is whole
   --  in view, after a key or type-ahead moved the selection, or a step set
   --  it by name (Files.Model.Reveal_Is_Pending, which this clears).
   procedure Reveal_Selection (Runtime : in out Runtime_Window) is separate;

   --  Reveal_Selection when a step since the last reveal set the selection
   --  by name: a reload that named its item, a mouse or menu command.
   procedure Reveal_Pending_Selection (Runtime : in out Runtime_Window) is separate;

   --  A settings change a held key's repeats made is in force but not yet
   --  written (Files.Model.Settings_Pane.Defer_Save): saved here, as Save
   --  would, once the key is let go, or with Force at once (the window
   --  closing, another key pressed, a mouse button pressed or released).
   procedure Save_Held_Settings (Runtime : in out Runtime_Window; Force : Boolean) is separate;

   --  Run the window's key presses and typed text in the order they arrived.
   procedure Handle_Keyboard
     (Runtime : in out Runtime_Window)
   is separate;

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
   --  Each other window adopts them (Controller.Adopt_Shared_Settings): an
   --  open settings pane there is refreshed, a listing whose options or type
   --  mappings changed is reloaded. Files.Application.Settings_Sharing.Share_From makes
   --  the decisions. Only windows from From on take them (a window being
   --  closed in turn hands them to those not closed yet).
   procedure Share_Settings_From
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      Index           : Positive;
      From            : Positive := Positive'First)
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

   --  Handle_Keyboard for every window.
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
      if Files.Model.Selection.Type_Ahead_Buffer (Runtime.Model) /= ""
        and then Ada.Real_Time.Clock > Runtime.Type_Ahead_Input_At + Type_Ahead_Timeout
      then
         Files.Model.Selection.Reset_Type_Ahead (Runtime.Model);
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
      Result : Files.Interaction.Interaction_Result;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      --  Left queued while an overlay owns the input, not lost.
      Files.Interaction.Import_Drops
        (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path), Runtime.Handle.Drop_Source, Result);
   end Handle_Drop_Input;

   --  Import the files dropped on every window.
   procedure Handle_All_Drop_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Drop_Input'Access);
   end Handle_All_Drop_Input;

   procedure Release_Window_Jobs
     (Model : in out Files.Model.Window_Model;
      Watch : in out Files.Refresh.Watch.Watch_Session) is separate;

   --  Poll every window's watched directory for changes.
   procedure Handle_All_File_Watch_Poll
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Watch.Poll'Access);
   end Handle_All_File_Watch_Poll;

   --  How long the event loop may wait for input: Paste_Wait_Timeout while
   --  any window carries out a paste through a helper process, else
   --  Event_Wait_Timeout, cut short to when a held-back mouse release
   --  (Guikit.Input.Mouse_Buttons.Ready_At) may be handled. Files.Application.Event_Wait
   --  decides each window's part.
   function Event_Loop_Wait (Runtime_Windows : Runtime_Window_Vectors.Vector) return Duration is separate;

   --  Each window polls its own background work -- the selected item's
   --  details, folder measurements and the Quick Look decode -- and publishes
   --  only its own results. It runs after the folder watch (Watch.Poll), so
   --  the details also serve a selection a cancelled or failed refresh
   --  deferred there.
   procedure Poll_Window_Workers (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
      procedure Poll (Runtime : in out Runtime_Window) is
      begin
         if Runtime.Handle /= null then
            --  The details wait out a foreground job (a paste, a delete),
            --  as the folder watch does: what the job changes is read once
            --  it is done.
            if not Files.Model.Jobs.Foreground_Job_Is_Active (Runtime.Model) then
               Files.Application.Window_Polls.Poll_Selected_Item_Extra
                 (Runtime.Model, Files.Application.Extra_Info_Reader.Requester (Runtime.A11y_Key),
                  Runtime.Settings.Show_Hidden_Files);
            end if;
            --  It asks for nothing while the targets it set still stand
            --  (Targets_Set_For) or a read or job is under way.
            Files.Application.Window_Polls.Update_Folder_Size (Runtime.Model);
            Files.Application.Window_Polls.Poll_Folder_Sizes (Runtime.Model);
            --  A window this loop polls has its tree's children read by
            --  the worker: an expand only asks.
            Files.Model.Tree_Panel.Load_In_Background (Runtime.Model);
            Files.Application.Window_Polls.Poll_Tree_Children
              (Runtime.Model, Runtime.Settings, Files.Application.Tree_Reader.Requester (Runtime.A11y_Key));
            Files.Application.Window_Polls.Poll_Quick_Look
              (Runtime.Model, Files.Application.Preview_Decoder.Requester (Runtime.A11y_Key));
         end if;
      end Poll;
   begin
      For_Each_Window (Runtime_Windows, Poll'Access);
   end Poll_Window_Workers;

   procedure Save_Pending_Zoom (Runtime : in out Runtime_Window; Force : Boolean) is separate;
   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
 is separate;

   --  Apply every window's pending scroll.
   procedure Handle_All_Scroll_Input
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      For_Each_Window (Runtime_Windows, Handle_Scroll_Input'Access);
   end Handle_All_Scroll_Input;

   procedure Dispatch_Click_Action
     (Runtime  : in out Runtime_Window;
      Action   : Files.Input_Actions.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set)
   is
      Result : Files.Interaction.Interaction_Result;
      Armed  : Boolean;
   begin
      --  A drag's begin arms the gesture the window layer tracks frame by
      --  frame (Gestures); every other action goes to the model.
      Gestures.Arm (Runtime, Action, Armed);
      if Armed then
         return;
      end if;

      Files.Interaction.Apply_Input_Action
        (Model             => Runtime.Model,
         Settings          => Runtime.Settings,
         Settings_Path     => To_String (Runtime.Settings_Path),
         Action            => Action,
         Modifiers         => Modifiers,
         Result            => Result);
      Flush_System_Clipboard (Runtime);
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

   function Hit_Position_At
     (Runtime  : in out Runtime_Window;
      Window_W : Glfw.Size;
      Window_H : Glfw.Size;
      Frame_W  : Glfw.Size;
      Frame_H  : Glfw.Size;
      Cursor_X : Glfw.Input.Mouse.Coordinate;
      Cursor_Y : Glfw.Input.Mouse.Coordinate)
      return Hit_Position
 is separate;

   function Current_Click_Action
     (Runtime   : in out Runtime_Window;
      Window_W  : Glfw.Size;
      Window_H  : Glfw.Size;
      Frame_W   : Glfw.Size;
      Frame_H   : Glfw.Size;
      Cursor_X  : Glfw.Input.Mouse.Coordinate;
      Cursor_Y  : Glfw.Input.Mouse.Coordinate;
      Modifiers : Guikit.Input.Modifier_Set)
      return Files.Input_Actions.Input_Action
 is separate;

   --  Carry out what the screen reader asked, as a click on the node's centre
   --  would: "focus" selects it, "activate" also opens an item (as a double
   --  click does) or presses a button.
   procedure Perform_Accessibility_Request
     (Runtime : in out Runtime_Window;
      Item    : A11ykit.Provider.Request)
   is separate;

   procedure Resolve_Drag_Source (Runtime : in out Runtime_Window) is separate;

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
               --  Closing saved its size or zoom, which may have taken in
               --  another process's change: the windows left take it too.
               Share_Settings_From (Runtime_Windows, Index);
               Runtime_Windows.Delete (Index);
            end if;
         end;
      end loop;
   end Release_Closed_Windows;

   procedure Release_All (Runtime_Windows : in out Runtime_Window_Vectors.Vector) is
   begin
      --  Each window's scan ends with the window (Release_Window). What its
      --  closing saved (and took in from another process) goes to the
      --  windows not closed yet, whose own saves would write it back.
      for Index in Runtime_Windows.First_Index .. Runtime_Windows.Last_Index loop
         Release_Window (Runtime_Windows (Index));
         Share_Settings_From (Runtime_Windows, Index, From => Index + 1);
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
      Handle   : Window_Access := new Desktop_Window;
      --  Whether the window's entry is in Runtime_Windows yet: a failure
      --  after that takes it out again, so nothing is left holding the
      --  handle freed below.
      Appended : Boolean := False;
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
      Files.Application.Window_Icon.Set (As_Window (Handle));
      Glfw.Windows.Content_Scale.Watch (As_Window (Handle));
      --  One more than a drop may hold, so an oversized one can be refused.
      Glfw.Windows.Drop.Paths.Watch (As_Window (Handle), Handle, Limit => Files.Drop_Events.Max_Paths + 1);
      Glfw.Windows.Show (As_Window (Handle));
      Runtime_Windows.Append
        (Runtime_Window'
           (Handle          => Handle,
            A11y_Key        => Files.Application.Accessibility.New_Window_Key,
            Model           => Startup_Window.Model,
            Settings        => Settings,
            Synced_Settings_Revision => Files.Model.Settings_Revision (Startup_Window.Model),
            Settings_Path   => Settings_Path,
            Font_Pixel_Size => Settings.Font_Pixel_Size,
            Shown           => True,
            others          => <>));
      Appended := True;
      Files.Model.Jobs.Set_Background_Transfers
        (Runtime_Windows.Reference (Runtime_Windows.Last_Index).Model, True);
      --  The screen reader looks at the window itself; answer it there.
      Files.Application.Accessibility.Attach_Window
        (Runtime_Windows.Reference (Runtime_Windows.Last_Index).A11y_Key,
         Glfw.Windows.Native.Handle (As_Window (Handle)));
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Application.Windows");
         if Appended then
            Files.Application.Accessibility.Forget (Runtime_Windows.Last_Element.A11y_Key);
            Runtime_Windows.Delete_Last;
         end if;
         if Handle /= null then
            if Glfw.Windows.Initialized (As_Window (Handle)) then
               Glfw.Windows.Drop.Paths.Forget (As_Window (Handle));
               Glfw.Windows.Destroy (As_Window (Handle));
            end if;

            Free_Window (Handle);
         end if;

         raise Desktop_Error with "error.window.create";
   end Append_Runtime_Window;

   --  Append a component overlay's draw commands (its rectangles, text, icons and
   --  accessibility nodes) onto the window frame.
   procedure Append_Overlay
     (Frame         : in out Files.Rendering.Frame_Commands;
      Rectangles    : Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : Guikit.Draw.Accessibility_Node_Vectors.Vector;
      Icons         : Guikit.Draw.Icon_Command_Vectors.Vector :=
        Guikit.Draw.Icon_Command_Vectors.Empty_Vector)
   is
      --  Panels (command palette, settings) draw into the overlay layer, which
      --  is composited after all of the main layer's rectangles, icons and
      --  text, so nothing of the file view shows through an opaque panel; their
      --  icons go to the overlay icon pass, above the panel's own background.
      --  Each vector grows once to its new length, and the rectangles, text
      --  and accessibility nodes go over whole.
      use type Ada.Containers.Count_Type;
   begin
      Frame.Overlay_Rectangles.Append_Vector (Rectangles);
      Frame.Overlay_Text.Append_Vector (Text);
      Frame.Icons.Reserve_Capacity (Frame.Icons.Length + Icons.Length);
      for C of Icons loop
         declare
            Command : Guikit.Draw.Icon_Command := C;
         begin
            Command.Overlay := True;
            Frame.Icons.Append (Command);
         end;
      end loop;
      Frame.Accessibility.Append_Vector (Accessibility);
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
         Frame.Overlay_Rectangles.Append (Files.Rendering.Modal_Backdrop (Width, Height));
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
     (Files.Application.Window_Policy.Capabilities_Of (Live_Display_Available, Vulkan_Runtime_Available));

   procedure Event_Loop_Pass
     (Runtime_Windows : in out Runtime_Window_Vectors.Vector;
      State           : in out Event_Loop_State) is
   begin
      Files.Application.Accessibility.Service;
      declare
         use type Files.Application.Accessibility.Window_Key;
         Request : A11ykit.Provider.Request;
         Window  : Files.Application.Accessibility.Window_Key;
      begin
         while Files.Application.Accessibility.Next_Request (Window, Request) loop
            for Runtime of Runtime_Windows loop
               if Runtime.A11y_Key = Window then
                  Perform_Accessibility_Request (Runtime, Request);
               end if;
            end loop;
         end loop;
      end;
      declare
         Focused : Files.Application.Accessibility.Window_Key := 0;
      begin
         for Runtime of Runtime_Windows loop
            if Runtime.Handle /= null and then Glfw.Windows.Focused (As_Window (Runtime.Handle)) then
               Focused := Runtime.A11y_Key;
            end if;
         end loop;
         Files.Application.Accessibility.Set_Active (Focused);
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
         if Files.Jobs.Scavenger.Has_Unrecoverable then
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
      Files.Application.Accessibility.Start;

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           =>
              (if Startup.Settings.Window_Width > 0
               then Startup.Settings.Window_Width
               else Files.Rendering.Layouts.Default_Window_Width),
            Height          =>
              (if Startup.Settings.Window_Height > 0
               then Startup.Settings.Window_Height
               else Files.Rendering.Layouts.Default_Window_Height));
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

      Files.Application.Accessibility.Stop;
      Release_All (Runtime_Windows);
      Glfw.Shutdown;
   exception
      when Desktop_Error =>
         Files.Application.Accessibility.Stop;
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise;
      when others =>
         Files.Application.Accessibility.Stop;
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         raise Desktop_Error with "error.window.create";
   end Run;

end Files.Application.Windows;
