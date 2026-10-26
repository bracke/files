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
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;
      use type Guikit.Draw.Text_Command_Vectors.Vector;
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

      Cancel_Background_Gestures_For_Overlay (Runtime);

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

      declare
         Hover_X  : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Width);
         Hover_Y  : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Height);
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         Has_Hover_Now : constant Boolean :=
           Width > 0 and then Height > 0
           and then Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H);
         Has_Press_Now : constant Boolean := Mouse_Down and then Has_Hover_Now;
         Has_Drag_Now  : constant Boolean :=
           Mouse_Down
           and then Runtime.Drag_Source_Index /= 0
           and then Runtime.Handle.Drag_Moved;
         Current_Minute : constant Natural := Wall_Clock_Minute;
         Inputs_Match : constant Boolean :=
           Runtime.Frame_Cache_Valid
           and then Runtime.Cached_Minute = Current_Minute
           and then Runtime.Cached_Frame_W = Natural (Width)
           and then Runtime.Cached_Frame_H = Natural (Height)
           and then Runtime.Cached_Line_Height = Line_Height
           and then Runtime.Cached_Hover_X = Hover_X
           and then Runtime.Cached_Hover_Y = Hover_Y
           and then Runtime.Cached_Has_Hover = Has_Hover_Now
           and then Runtime.Cached_Has_Press = Has_Press_Now
           and then Runtime.Cached_Drag_Item = Runtime.Drag_Source_Index
           and then Runtime.Cached_Has_Drag = Has_Drag_Now
           and then Runtime.Cached_Marquee_Active = Runtime.Marquee_Active
           and then Runtime.Cached_Marquee_X = Runtime.Marquee_Rect_X
           and then Runtime.Cached_Marquee_Y = Runtime.Marquee_Rect_Y
           and then Runtime.Cached_Marquee_W = Runtime.Marquee_Rect_W
           and then Runtime.Cached_Marquee_H = Runtime.Marquee_Rect_H;

         --  Rebuild the cached frame from Snapshot and record the input keys it
         --  was built for. Snapshot is an in-parameter (passed by reference, not
         --  copied here).
         procedure Rebuild_Frame (Snapshot : Files.Rendering.View_Snapshot) is
         begin
            Frame_Rebuilt := True;
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
                 Has_Press   => Has_Press_Now,
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
            Runtime.Cached_Has_Press := Has_Press_Now;
            Runtime.Cached_Drag_Item := Runtime.Drag_Source_Index;
            Runtime.Cached_Has_Drag := Has_Drag_Now;
            Runtime.Cached_Marquee_Active := Runtime.Marquee_Active;
            Runtime.Cached_Marquee_X := Runtime.Marquee_Rect_X;
            Runtime.Cached_Marquee_Y := Runtime.Marquee_Rect_Y;
            Runtime.Cached_Marquee_W := Runtime.Marquee_Rect_W;
            Runtime.Cached_Marquee_H := Runtime.Marquee_Rect_H;
            Runtime.Cached_Minute := Current_Minute;
            Runtime.Frame_Cache_Valid := True;
         end Rebuild_Frame;
      begin
         --  Build_Snapshot is O(items) with a sort and per-item work, so the
         --  snapshot is rebuilt only when the model, the snapshot settings or
         --  the minute moved since it was built -- here or by an input handler
         --  since the last frame (Refresh_Snapshot). The animations above
         --  (paste progress, marquee drag) bump the revision, or, for paste
         --  progress, make Refresh_Snapshot rebuild while it runs.
         Refresh_Snapshot (Runtime);
         declare
            Current : Files.Rendering.View_Snapshot renames Runtime.Snapshots (Runtime.Current_Slot);
         begin
            if Runtime.Current_Slot = Runtime.Drawn_Slot then
               --  The snapshot is the one drawn last: reuse it in place -- no
               --  per-frame deep copy or deep compare (thumbnail pixels and
               --  all). Rebuild the frame only if a non-model input (size,
               --  hover, drag, marquee) changed.
               if not Inputs_Match then
                  Rebuild_Frame (Current);
               end if;
            else
               --  A rebuilt snapshot: draw it unless it equals what is drawn.
               if not Inputs_Match or else Current /= Runtime.Snapshots (Runtime.Drawn_Slot) then
                  Rebuild_Frame (Current);
               end if;
               Runtime.Drawn_Slot := Runtime.Current_Slot;
            end if;
         end;
      end;

      --  Anything that changes what is on screen -- a rebuilt frame, an open (or
      --  just-closed) overlay, or text still settling -- opens the grace window,
      --  so we keep presenting every frame through it and stay on the compositor's
      --  frame clock while the user is interacting.
      if Frame_Rebuilt
        or else Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Command_Palette_Overlay)
        or else Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Settings_Pane_Overlay)
        or else Runtime.Last_Present_Palette_Open
        or else Runtime.Last_Present_Settings_Open
        or else (not Runtime.Text_Ready
                 and then (Runtime.Text_Failed_Size /= Runtime.Font_Pixel_Size
                           or else Ada.Real_Time.Clock - Runtime.Text_Failed_At >= Text_Retry_Interval))
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

      declare
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.Snapshots (Runtime.Drawn_Slot);
         --  Whether an overlay is merged in below, so the frame shown differs
         --  from the cached one.
         Overlay_Merged : constant Boolean :=
           Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Command_Palette_Overlay)
           or else Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Settings_Pane_Overlay);

         procedure Present (Frame : Files.Rendering.Frame_Commands) is
         begin
            --  The screen reader gets the frame as shown, overlays included --
            --  the command palette and settings panel are merged in by the
            --  caller, not into the cached frame -- when it changed, an
            --  overlay (whose state changes from frame to frame) is up, or one
            --  just closed. The provider announces only what differs from its
            --  last tree.
            if Frame_Rebuilt
              or else Overlay_Merged
              or else Runtime.Last_Present_Palette_Open
              or else Runtime.Last_Present_Settings_Open
            then
               Files.Accessibility.Publish (Runtime.A11y_Key, Frame);
               Runtime.Shown_Accessibility := Frame.Accessibility;
            end if;
            --  A title change is a round trip to the window system.
            if Snapshot.Current_Path /= Runtime.Shown_Title then
               Glfw.Windows.Set_Title (As_Window (Runtime.Handle), To_String (Snapshot.Current_Path));
               Runtime.Shown_Title := Snapshot.Current_Path;
            end if;

            Guikit.Vulkan.Ensure_Ready
              (Renderer => Runtime.Vulkan,
               Window   => As_Window (Runtime.Handle),
               Width    => Natural (Width),
               Height   => Natural (Height));

            begin
               --  Loaded once per window (a pooled renderer per size, so this is
               --  cheap when another window already has the size); a failure
               --  is retried after a pause, not every frame.
               if not Runtime.Text_Ready
                 and then (Runtime.Text_Failed_Size /= Runtime.Font_Pixel_Size
                           or else Ada.Real_Time.Clock - Runtime.Text_Failed_At >= Text_Retry_Interval)
               then
                  declare
                     Status : constant Files.Rendering.Text_Render_Status :=
                       Files.Rendering.Initialize_Text
                         (Renderer    => Runtime.Text,
                          Font_Path   => Files.Rendering.Default_Font_Path,
                          Pixel_Size  => Runtime.Font_Pixel_Size,
                          Cell_Width  => Cell_Width_For (Runtime.Font_Pixel_Size),
                          Cell_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
                  begin
                     Runtime.Text_Ready := Status = Files.Rendering.Text_Render_Success;
                     Runtime.Glyph_Text_Valid := False;
                     Runtime.Text_Failed_Size := (if Runtime.Text_Ready then 0 else Runtime.Font_Pixel_Size);
                     Runtime.Text_Failed_At := Ada.Real_Time.Clock;
                  end;
               end if;

               declare
                  --  Without text (no font yet, a failed load) the frame is
                  --  still drawn: a window with no labels, not a blank one.
                  Glyphs : Files.Rendering.Text_Render_Result;
               begin
                  if Runtime.Text_Ready then
                     --  Unchanged text reuses its glyphs; the renderer uploads
                     --  the atlas only when its version moved (or an earlier
                     --  present failed).
                     if Runtime.Glyph_Text_Valid
                       and then Runtime.Glyph_Text = Frame.Text
                       and then Runtime.Glyph_Overlay_Text = Frame.Overlay_Text
                       and then Runtime.Text_Glyphs.Status = Files.Rendering.Text_Render_Success
                       and then Files.Rendering.Text_Glyphs_Current (Runtime.Text, Runtime.Text_Glyphs)
                     then
                        Glyphs := Runtime.Text_Glyphs;
                     else
                        Glyphs := Files.Rendering.Build_Text_Glyphs (Runtime.Text, Frame);
                        Runtime.Text_Glyphs := Glyphs;
                        Runtime.Glyph_Text := Frame.Text;
                        Runtime.Glyph_Overlay_Text := Frame.Overlay_Text;
                        Runtime.Glyph_Text_Valid := True;
                        --  Its pooled fonts went to another size and did not
                        --  load again: a failure like the first, retried after
                        --  the same pause, not on every frame (nor never).
                        if not Files.Rendering.Text_Loaded (Runtime.Text) then
                           Runtime.Text_Ready := False;
                           Runtime.Glyph_Text_Valid := False;
                           Runtime.Text_Failed_Size := Runtime.Font_Pixel_Size;
                           Runtime.Text_Failed_At := Ada.Real_Time.Clock;
                        end if;
                     end if;
                  end if;

                  declare
                     Batch : constant Guikit.Vulkan.Submission_Batch :=
                       Guikit.Vulkan.Build_Submission
                         (Rectangles         => Frame.Rectangles,
                          Triangles          => Frame.Triangles,
                          Icons              => Frame.Icons,
                          Overlay_Rectangles => Frame.Overlay_Rectangles,
                          Layout             => Frame.Layout,
                          Theme              => Frame.Theme_Palette,
                          Text               => Glyphs);
                  begin
                     Runtime.Last_Glyph_Count := Natural (Glyphs.Glyphs.Length);
                     Runtime.Last_Missing_Glyph_Count := Glyphs.Missing_Glyph_Count;
                     Runtime.Last_Present_Status :=
                       Guikit.Vulkan.Present_Frame
                         (Renderer => Runtime.Vulkan,
                          Batch    => Batch,
                          Width    => Natural (Width),
                          Height   => Natural (Height));

                     if Runtime.Last_Present_Status /= Guikit.Vulkan.Vulkan_Presented then
                        Runtime.Fallback_Frames := Runtime.Fallback_Frames + 1;
                     end if;
                  end;
               end;
            end;

         end Present;
      begin
         if Overlay_Merged then
            declare
               --  A working copy of the cached frame, so an overlay (whose state
               --  lives in its component and changes every frame) is merged in
               --  fresh without polluting the cache.
               Frame : Files.Rendering.Frame_Commands := Runtime.Cached_Frame;
            begin
               if Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Command_Palette_Overlay) then
                  declare
                     Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
                     Layout : constant Files.Rendering.Layout_Metrics :=
                       Files.Rendering.Calculate_Layout
                         (Snapshot, Natural (Width), Natural (Height), Line_Height);
                     P_Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
                     P_Text  : Guikit.Draw.Text_Command_Vectors.Vector;
                     P_Icons : Guikit.Draw.Icon_Command_Vectors.Vector;
                     P_Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
                  begin
                     Append_Modal_Backdrop (Frame, Natural (Width), Natural (Height));
                     Files.Model.Palette_Build_Frame
                       (Model         => Runtime.Model,
                        Region_X      => Layout.Command_X,
                        Region_Y      => Layout.Command_Y,
                        Region_Width  => Layout.Command_Width,
                        Region_Height => Layout.Command_Height,
                        Clip_Width    => Natural (Width),
                        Clip_Height   => Natural (Height),
                        Line_Height   => Line_Height,
                        Focused       =>
                          Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Command_Palette,
                        Rectangles    => P_Rects,
                        Text          => P_Text,
                        Icons         => P_Icons,
                        Accessibility => P_Nodes);
                     Append_Overlay (Frame, P_Rects, P_Text, P_Nodes, P_Icons);
                  end;
               end if;

               --  Settings remains logically open when Commands is invoked from it,
               --  but Commands is the active top-level modal and owns the pixels until
               --  it closes. Rendering both would interleave their batched text layers.
               if Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Settings_Pane_Overlay) then
                  declare
                     Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
                     Layout : constant Files.Rendering.Layout_Metrics :=
                       Files.Rendering.Calculate_Layout
                         (Snapshot, Natural (Width), Natural (Height), Line_Height);
                     Pane : constant Guikit.Layout.Settings_Pane_Layout :=
                       Guikit.Layout.Calculate_Settings_Pane_Layout
                         (Natural (Width), Natural (Height), Layout.Toolbar_Height, Line_Height);
                     S_Rects : Guikit.Draw.Rectangle_Command_Vectors.Vector;
                     S_Text  : Guikit.Draw.Text_Command_Vectors.Vector;
                     S_Nodes : Guikit.Draw.Accessibility_Node_Vectors.Vector;
                  begin
                     Append_Modal_Backdrop (Frame, Natural (Width), Natural (Height));
                     Files.Model.Settings_Build_Frame
                       (Model         => Runtime.Model,
                        Region_X      => Pane.X,
                        Region_Y      => Pane.Y,
                        Region_Width  => Pane.Width,
                        Region_Height => Pane.Height,
                        Clip_Width    => Natural (Width),
                        Clip_Height   => Natural (Height),
                        Line_Height   => Line_Height,
                        Focused       =>
                          Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Settings_Input,
                        Hover_X       =>
                          (if Runtime.Cached_Has_Hover then Integer (Runtime.Cached_Hover_X) else -1),
                        Hover_Y       =>
                          (if Runtime.Cached_Has_Hover then Integer (Runtime.Cached_Hover_Y) else -1),
                        Rectangles    => S_Rects,
                        Text          => S_Text,
                        Accessibility => S_Nodes);
                     Append_Overlay (Frame, S_Rects, S_Text, S_Nodes);
                  end;
               end if;

               Present (Frame);
            end;
         else
            --  Nothing to merge: present the cached frame itself, uncopied.
            Present (Runtime.Cached_Frame);
         end if;

         --  Remember what we just put on screen so the next render's present gate
         --  can tell whether an overlay closed (a change that must be presented).
         Runtime.Presented_Once := True;
         Runtime.Last_Present_Palette_Open :=
           Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Command_Palette_Overlay);
         Runtime.Last_Present_Settings_Open :=
           Files.Model.Window_Overlay_Shown (Runtime.Model, Files.Model.Settings_Pane_Overlay);

         --  Burn down one frame of the grace window. It is refilled above on any
         --  visible change, so it only reaches zero after a genuine idle gap.
         if Runtime.Present_Grace > 0 then
            Runtime.Present_Grace := Runtime.Present_Grace - 1;
         end if;
      end;
   end Render_Window;
