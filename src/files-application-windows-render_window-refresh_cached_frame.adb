separate (Files.Application.Windows.Render_Window)
   procedure Refresh_Cached_Frame
   is
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
      Inputs : constant Frame_Inputs :=
        (Width          => Natural (Width),
         Height         => Natural (Height),
         Line_Height    => Line_Height,
         Hover_X        => Hover_X,
         Hover_Y        => Hover_Y,
         Has_Hover      => Has_Hover_Now,
         Has_Press      => Has_Press_Now,
         Drag_Item      => Runtime.Drag_Source_Index,
         Has_Drag       => Has_Drag_Now,
         Marquee_Active => Runtime.Marquee.Active,
         Marquee_X      => Runtime.Marquee.Rect_X,
         Marquee_Y      => Runtime.Marquee.Rect_Y,
         Marquee_W      => Runtime.Marquee.Rect_W,
         Marquee_H      => Runtime.Marquee.Rect_H);
      Inputs_Match : constant Boolean :=
        Runtime.Frame_Cache_Valid
        and then Runtime.Cached_Minute = Current_Minute
        and then Runtime.Cached_Inputs = Inputs;

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
              Pointer =>
                (Hover_X => Hover_X,
                 Hover_Y => Hover_Y,
                 Has_Hover => Has_Hover_Now,
                 Pressed_X => Hover_X,
                 Pressed_Y => Hover_Y,
                 Has_Press => Has_Press_Now,
                 Drag_Item_Index => Runtime.Drag_Source_Index,
                 Drag_X => Hover_X,
                 Drag_Y => Hover_Y,
                 Has_Drag => Has_Drag_Now,
                 Marquee_Active => Runtime.Marquee.Active,
                 Marquee_X => Runtime.Marquee.Rect_X,
                 Marquee_Y => Runtime.Marquee.Rect_Y,
                 Marquee_W => Runtime.Marquee.Rect_W,
                 Marquee_H => Runtime.Marquee.Rect_H));
         Runtime.Cached_Inputs := Inputs;
         Runtime.Cached_Minute := Current_Minute;
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
