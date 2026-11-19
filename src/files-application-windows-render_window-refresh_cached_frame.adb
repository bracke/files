separate (Files.Application.Windows.Render_Window)
   procedure Refresh_Cached_Frame
   is
      Hover_X  : constant Natural := Files.Window_Policy.Scale_X (Cursor_X, Window_W, Width);
      Hover_Y  : constant Natural := Files.Window_Policy.Scale_Coordinate (Cursor_Y, Window_H, Height);
      Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      Has_Hover_Now : constant Boolean :=
        Width > 0 and then Height > 0
        and then Files.Window_Policy.Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H);
      Has_Drag_Now  : constant Boolean :=
        Mouse_Down
        and then Runtime.Drag_Source_Index /= 0
        and then Runtime.Handle.Drag_Moved;
      --  The command palette and the settings pane, merged over the frame
      --  by the window layer, own the pointer while shown: the frame under
      --  them is drawn with no hover or press.
      Window_Overlay_Up : constant Boolean :=
        Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Command_Palette_Overlay)
        or else Files.Model.Window_Overlay_Shown (Runtime.Model, Files.UI_Types.Settings_Pane_Overlay);
      Frame_Hover   : constant Boolean := Has_Hover_Now and then not Window_Overlay_Up;
      Has_Press_Now : constant Boolean := Mouse_Down and then Frame_Hover;
      --  The pointer's position is kept only where the frame reads it: under
      --  hover, or for the drag preview that follows it. Anywhere else (off
      --  the window, where X11 still reports it, or under the palette or
      --  settings pane) it is 0, so moving it there rebuilds nothing.
      Track_Pointer : constant Boolean := Frame_Hover or else Has_Drag_Now;
      Inputs : constant Frame_Inputs :=
        (Width       => Natural (Width),
         Height      => Natural (Height),
         Line_Height => Line_Height,
         Pointer     =>
           (Hover_X         => (if Track_Pointer then Hover_X else 0),
            Hover_Y         => (if Track_Pointer then Hover_Y else 0),
            Has_Hover       => Frame_Hover,
            Pressed         => Has_Press_Now,
            Press_X         => (if Has_Press_Now then Runtime.Press_X else 0),
            Press_Y         => (if Has_Press_Now then Runtime.Press_Y else 0),
            --  The drag source and the marquee's rectangle, like the
            --  position, only while the frame draws them: a plain press on an
            --  item sets the drag source, which must not rebuild the frame.
            Dragging        => Has_Drag_Now,
            Drag_Item_Index => (if Has_Drag_Now then Runtime.Drag_Source_Index else 0),
            Marquee_Active  => Runtime.Marquee.Active,
            Marquee_X       => (if Runtime.Marquee.Active then Runtime.Marquee.Rect_X else 0),
            Marquee_Y       => (if Runtime.Marquee.Active then Runtime.Marquee.Rect_Y else 0),
            Marquee_W       => (if Runtime.Marquee.Active then Runtime.Marquee.Rect_W else 0),
            Marquee_H       => (if Runtime.Marquee.Active then Runtime.Marquee.Rect_H else 0)));
      Inputs_Match : constant Boolean :=
        Runtime.Frame_Cache_Valid and then Runtime.Cached_Inputs = Inputs;

      --  Rebuild the cached frame from Snapshot and record the input keys it
      --  was built for. Snapshot is an in-parameter (passed by reference, not
      --  copied here).
      procedure Rebuild_Frame (Snapshot : Files.Rendering.View_Snapshot) is
      begin
         Frame_Rebuilt := True;
         Runtime.Cached_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Snapshot    => Snapshot,
              Width       => Inputs.Width,
              Height      => Inputs.Height,
              Line_Height => Inputs.Line_Height,
              Pointer     => Inputs.Pointer);
         Runtime.Cached_Inputs := Inputs;
         Runtime.Frame_Cache_Valid := True;
         --  With the key and presented= traces, CI checks that the frame
         --  shown after a key is one drawn with the selection it moved to.
         --  The index is the one in the snapshot the frame was built from
         --  (Build_Snapshot copies Files.Model.Selection.Selected_Index into it, so
         --  the numbering is the selected= trace's), not the model's now:
         --  a frame rebuilt from a stale snapshot shows the stale index.
         declare
            Shown : constant String := Natural'Image (Snapshot.Primary_Selected_Visible_Index);
         begin
            Files.Diagnostics.Trace
              ("Files.Application.Windows", "drawn-selection=" & Shown (Shown'First + 1 .. Shown'Last));
         end;
      end Rebuild_Frame;
   begin
      --  The window-layer overlays read the pointer unmasked: the settings
      --  pane draws its own hover.
      Overlay_Pointer :=
        (Hover_X   => Hover_X,
         Hover_Y   => Hover_Y,
         Has_Hover => Has_Hover_Now,
         others    => <>);
      --  Build_Snapshot is O(items) with a sort and per-item work, so the
      --  snapshot is rebuilt only when the model, the snapshot settings or
      --  the minute moved since it was built -- here or by an input handler
      --  since the last frame (Refresh_Snapshot). The animations above
      --  (paste progress, marquee drag) bump the revision, or, for paste
      --  progress, make Refresh_Snapshot rebuild while it runs.
      Refresh_Snapshot (Runtime);
      declare
         Current : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Current_Slot);
      begin
         if Runtime.View.Current_Slot = Runtime.View.Drawn_Slot then
            --  The snapshot is the one drawn last: reuse it in place -- no
            --  per-frame deep copy or deep compare (thumbnail pixels and
            --  all). Rebuild the frame only if a non-model input (size,
            --  hover, drag, marquee) changed.
            if not Inputs_Match then
               Rebuild_Frame (Current);
            end if;
         else
            --  A rebuilt snapshot: draw it unless it equals what is drawn.
            if not Inputs_Match or else Current /= Runtime.View.Snapshots (Runtime.View.Drawn_Slot) then
               Rebuild_Frame (Current);
            end if;
            Runtime.View.Drawn_Slot := Runtime.View.Current_Slot;
         end if;
      end;
   end Refresh_Cached_Frame;
