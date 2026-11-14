separate (Files.Application.Windows)
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
      --  Set when the cached frame is (re)built this render; drives the decision
      --  to re-present, so an idle frame whose commands are unchanged skips the
      --  glyph/vertex/submit/present work entirely.
      Frame_Rebuilt : Boolean := False;
      --  The overlays this render shows, and whether they differ from the
      --  ones last presented.
      Palette         : Overlay_Commands;
      Settings        : Overlay_Commands;
      Overlay_Changed : Boolean := False;

      use type Ada.Real_Time.Time_Span;
      use type Guikit.Draw.Text_Command_Vectors.Vector;

      --  Build the command palette's or the settings panel's commands, when
      --  shown, over the frame drawn now (their state lives in their
      --  components, not in the cached frame).
      procedure Build_Overlays is separate;

      --  Read the framebuffer and window sizes (rescaling text when the pixel
      --  ratio or the shared font size moved) and the pointer, and carry the
      --  scrollbar, column and marquee drags along with it.
      procedure Read_Window_State is separate;

      --  Bring the snapshot up to date and rebuild the cached frame when it,
      --  or a non-model input it was drawn for, changed.
      procedure Refresh_Cached_Frame is separate;

      --  Put the cached frame, with any overlay merged in, on screen.
      procedure Present_Frame is separate;
   begin
      if Runtime.Handle = null
        or else not Glfw.Windows.Initialized (As_Window (Runtime.Handle))
        or else Glfw.Windows.Should_Close (As_Window (Runtime.Handle))
      then
         return;
      end if;

      Read_Window_State;

      --  Drive a long copy/move a few actions at a time so the UI stays
      --  responsive and the progress overlay animates. Small pastes have already
      --  finished (in Begin_Paste / Resolve_Paste_Conflict) and never get here.
      if Files.Model.Pasting.Execution_Is_Active (Runtime.Model) then
         declare
            Progress : constant Files.Operations.Operation_Result :=
              Files.Operations.Advance_Paste_Execution (Runtime.Model, Runtime.Settings, 8);
            pragma Unreferenced (Progress);
            --  A finished background move carries its labels along.
            Followed : constant Boolean :=
              Files.Interaction.Follow_Path_Moves (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path));
            pragma Unreferenced (Followed);
         begin
            null;
         end;
      end if;

      --  A changed free-space reading or owner name bumps the model revision,
      --  so the snapshot below is rebuilt only when what it shows has moved.
      Sample_Volume_Space (Runtime.Model);
      Sample_Account_Names (Runtime.Model);

      Refresh_Cached_Frame;

      --  Anything that changes what is on screen -- a rebuilt frame, an overlay
      --  that opened, closed or changed, or text still settling -- opens the grace window,
      --  so we keep presenting every frame through it and stay on the compositor's
      --  frame clock while the user is interacting.
      Build_Overlays;
      Overlay_Changed := Palette /= Runtime.Last_Palette or else Settings /= Runtime.Last_Settings;
      if Frame_Rebuilt
        or else Overlay_Changed
        or else (not Runtime.Text_Ready
                 and then (Runtime.Text_Failed_Size /= Runtime.Font_Pixel_Size
                           or else Ada.Real_Time.Clock >= Runtime.Text_Failed_At + Text_Retry_Interval))
      then
         Runtime.Present_Grace := Present_Grace_Frames;
      end if;

      --  Present gate: once the grace window has elapsed (nothing has changed for
      --  a while), the identical frame is already on screen -- skip the whole
      --  submit/present path. That is the idle saving: the loop still wakes each
      --  timeout, but an unchanging view no longer re-packs vertices or presents.
      if Runtime.Presented_Once
        and then Runtime.Present_Grace = 0
        and then not Guikit.Vulkan.Readback_Enabled (Runtime.Vulkan)
      then
         return;
      end if;

      Present_Frame;
   end Render_Window;
