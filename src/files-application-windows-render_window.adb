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
         --  Reuse the cached snapshot when the model and settings are unchanged
         --  since it was built. Build_Snapshot is O(items) with a sort and
         --  per-item work, so skipping it on unchanged frames is the main saving.
         --  The per-frame animations (paste progress, marquee drag) mutate the
         --  model as they run above, so always rebuild while they are active.
         Reuse_Snapshot : constant Boolean :=
           Runtime.Frame_Cache_Valid
           and then Runtime.Cached_Model_Revision = Files.Model.Revision (Runtime.Model)
           and then Files.Settings.Same_Snapshot_Settings
                      (Runtime.Settings, Runtime.Cached_Settings_Key)
           and then not Files.Model.Paste_Execution_Is_Active (Runtime.Model)
           and then not Runtime.Marquee_Active;
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
            --  Publish the new frame's accessibility tree to the host screen
            --  reader, only when the frame actually changed. A no-op until an
            --  a11ykit provider exists, so it costs nothing today.
            Files.Accessibility.Publish (Runtime.Cached_Frame);
         end Rebuild_Frame;
      begin
         if Reuse_Snapshot then
            --  Model + snapshot-relevant settings unchanged: the cached snapshot
            --  is still current, so reuse it in place -- no per-frame deep copy
            --  or deep compare of the whole snapshot (thumbnail pixels and all).
            --  Rebuild the frame only if a non-model input (size, hover, drag,
            --  marquee) changed.
            if not Inputs_Match then
               Rebuild_Frame (Runtime.Cached_Snapshot);
            end if;
         else
            declare
               Fresh : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
            begin
               if not Inputs_Match or else Fresh /= Runtime.Cached_Snapshot then
                  Runtime.Cached_Snapshot := Fresh;
                  Rebuild_Frame (Fresh);
               end if;
            end;
         end if;

         --  Cached_Snapshot now reflects the current model at this revision and
         --  these settings (it was reused, or just rebuilt above), so the next
         --  render reuses it until the model revision or a snapshot-relevant
         --  setting changes -- the whole of Build_Snapshot's inputs.
         Runtime.Cached_Model_Revision := Files.Model.Revision (Runtime.Model);
         Runtime.Cached_Settings_Key :=
           Files.Settings.Snapshot_Settings_Key_Of (Runtime.Settings);
      end;

      --  Anything that changes what is on screen -- a rebuilt frame, an open (or
      --  just-closed) overlay, or text still settling -- opens the grace window,
      --  so we keep presenting every frame through it and stay on the compositor's
      --  frame clock while the user is interacting.
      if Frame_Rebuilt
        or else Files.Model.Command_Palette_Is_Open (Runtime.Model)
        or else Files.Model.Settings_Pane_Is_Open (Runtime.Model)
        or else Runtime.Last_Present_Palette_Open
        or else Runtime.Last_Present_Settings_Open
        or else not Runtime.Text_Ready
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
         --  A working copy of the cached frame so the palette overlay (whose
         --  state lives in the component and changes every frame) can be merged
         --  in fresh without polluting the cache.
         Frame : Files.Rendering.Frame_Commands := Runtime.Cached_Frame;
         Snapshot : Files.Rendering.View_Snapshot renames Runtime.Cached_Snapshot;
      begin
         if Files.Model.Command_Palette_Is_Open (Runtime.Model) then
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

         if Files.Model.Settings_Pane_Is_Open (Runtime.Model) then
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
         Glfw.Windows.Set_Title (As_Window (Runtime.Handle), To_String (Snapshot.Current_Path));

         Guikit.Vulkan.Ensure_Ready
           (Renderer => Runtime.Vulkan,
            Window   => As_Window (Runtime.Handle),
            Width    => Natural (Width),
            Height   => Natural (Height));

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
            else
               Runtime.Last_Glyph_Count := 0;
               Runtime.Last_Missing_Glyph_Count := 0;
            end if;
         end;

         --  Remember what we just put on screen so the next render's present gate
         --  can tell whether an overlay closed (a change that must be presented).
         Runtime.Presented_Once := True;
         Runtime.Last_Present_Palette_Open :=
           Files.Model.Command_Palette_Is_Open (Runtime.Model);
         Runtime.Last_Present_Settings_Open :=
           Files.Model.Settings_Pane_Is_Open (Runtime.Model);

         --  Burn down one frame of the grace window. It is refilled above on any
         --  visible change, so it only reaches zero after a genuine idle gap.
         if Runtime.Present_Grace > 0 then
            Runtime.Present_Grace := Runtime.Present_Grace - 1;
         end if;
      end;
   end Render_Window;
