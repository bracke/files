separate (Files.Application.Windows)
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
      if not Runtime.Marquee.Active then
         return;
      elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Runtime.Marquee.Active := False;
         return;
      end if;

      X_Frame := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
      Y_Frame := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);

      if not Mouse_Down then
         --  Released: end the gesture and stop drawing the rectangle, keeping
         --  whatever selection the drag produced. A press that never crossed the
         --  threshold left the selection untouched, so an empty-space click that
         --  did not drag stays a no-op.
         Runtime.Marquee.Active := False;
         Runtime.Marquee.Rect_W := 0;
         Runtime.Marquee.Rect_H := 0;
         return;
      end if;

      if not Runtime.Marquee.Moved then
         if abs (X_Frame - Runtime.Marquee.Origin_X) > Marquee_Drag_Threshold
           or else abs (Y_Frame - Runtime.Marquee.Origin_Y) > Marquee_Drag_Threshold
         then
            Runtime.Marquee.Moved := True;
         else
            return;
         end if;
      end if;

      --  Held still, with no auto-scroll going: the band is where it was.
      --  Laying out every item to find that out again held a core.
      if X_Frame = Runtime.Marquee.Last_X
        and then Y_Frame = Runtime.Marquee.Last_Y
        and then Files.Model.Main_View_Scroll_Lines (Runtime.Model) = Runtime.Marquee.Last_Scroll
        and then not Runtime.Marquee.Auto_Scrolled
      then
         return;
      end if;
      Runtime.Marquee.Auto_Scrolled := False;

      --  The selection this drag move sets bumps the model revision, so the
      --  render that follows rebuilds the snapshot once; laying out here reuses
      --  the current one (normally the frame just drawn).
      Refresh_Snapshot (Runtime);
      declare
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);

         Layout    : Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Runtime.Snapshots (Runtime.Current_Slot), Natural (Frame_W), Natural (Frame_H), Line_Height);
         Main_View : Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout
             (Runtime.Snapshots (Runtime.Current_Slot), Layout, Line_Height);
      begin
         --  Auto-scroll: while the cursor is dragged to (or past) the top or
         --  bottom of the scrollable rows area, scroll the list so items beyond
         --  the current view can be rubber-banded in one gesture. The origin is
         --  kept anchored to the content it started on by shifting it opposite
         --  the actual scroll, so items already inside the band are not dropped
         --  as they move off screen. Nothing to do when it all fits (no bar).
         if Main_View.Scrollbar_Visible then
            declare
               Viewport_H : constant Natural := Main_View.Scrollbar_Track_Height;
               Content_H  : constant Natural := Main_View.Content_Height;
               Max_Lines  : constant Natural :=
                 (if Content_H > Viewport_H
                  then (Content_H - Viewport_H + Line_Height - 1) / Line_Height
                  else 0);
               Current    : constant Natural := Files.Model.Main_View_Scroll_Lines (Runtime.Model);
               Old_Px     : constant Natural := Main_View.Scroll_Pixels;
               Step       : constant Integer :=
                 Files.Rendering.Marquee_Auto_Scroll_Step
                   (Cursor_Y      => Y_Frame,
                    Region_Top    => Integer (Main_View.Scrollbar_Y),
                    Region_Bottom =>
                      Integer (Main_View.Scrollbar_Y) + Integer (Main_View.Scrollbar_Track_Height),
                    Line_Height   => Line_Height);
            begin
               if Step /= 0 then
                  declare
                     New_Lines : constant Natural :=
                       Natural
                         (Integer'Max
                            (0, Integer'Min (Integer (Current) + Step, Integer (Max_Lines))));
                  begin
                     if New_Lines /= Current then
                        Runtime.Marquee.Auto_Scrolled := True;
                        Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, New_Lines);
                        --  Rebuild against the new scroll, then re-anchor the
                        --  origin by the scroll's actual pixel shift (which the
                        --  renderer may snap to a row period, so measure it).
                        Refresh_Snapshot (Runtime);
                        Layout := Files.Rendering.Calculate_Layout
                          (Runtime.Snapshots (Runtime.Current_Slot), Natural (Frame_W), Natural (Frame_H),
                           Line_Height);
                        Main_View :=
                          Files.Rendering.Calculate_Main_View_Layout
                            (Runtime.Snapshots (Runtime.Current_Slot), Layout, Line_Height);
                        Runtime.Marquee.Origin_Y :=
                          Runtime.Marquee.Origin_Y
                          - (Integer (Main_View.Scroll_Pixels) - Integer (Old_Px));
                     end if;
                  end;
               end if;
            end;
         end if;

         declare
            --  Hit-tested in unscrolled content coordinates, against every
            --  item: a row the auto-scroll moved off screen has no area on
            --  screen but is still inside the band.
            Items  : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout
                (Runtime.Snapshots (Runtime.Current_Slot), Layout, Line_Height, Whole_Content => True);
            Scroll : constant Integer := Integer (Main_View.Scroll_Pixels);
            Band_X : Natural;
            Band_Y : Natural;
            Band_W : Natural;
            Band_H : Natural;
            Rect_X : Natural;
            Rect_Y : Natural;
            Rect_W : Natural;
            Rect_H : Natural;
         begin
            Files.Rendering.Marquee_Rect
              (Start_X   => Natural'Max (0, Runtime.Marquee.Origin_X),
               Start_Y   => Natural'Max (0, Runtime.Marquee.Origin_Y),
               Current_X => Natural'Max (0, X_Frame),
               Current_Y => Natural'Max (0, Y_Frame),
               X         => Rect_X,
               Y         => Rect_Y,
               Width     => Rect_W,
               Height    => Rect_H);
            Files.Rendering.Marquee_Rect
              (Start_X   => Natural'Max (0, Runtime.Marquee.Origin_X),
               Start_Y   => Natural'Max (0, Runtime.Marquee.Origin_Y + Scroll),
               Current_X => Natural'Max (0, X_Frame),
               Current_Y => Natural'Max (0, Y_Frame + Scroll),
               X         => Band_X,
               Y         => Band_Y,
               Width     => Band_W,
               Height    => Band_H);
            Files.Interaction.Apply_Marquee_Selection
              (Model    => Runtime.Model,
               Hits     =>
                 Files.Rendering.Hit.Items_In_Rect (Items, Band_X, Band_Y, Band_W, Band_H),
               Additive => Runtime.Marquee.Additive,
               Base     => Runtime.Marquee.Base);
            Runtime.Marquee.Rect_X := Rect_X;
            Runtime.Marquee.Rect_Y := Rect_Y;
            Runtime.Marquee.Rect_W := Rect_W;
            Runtime.Marquee.Rect_H := Rect_H;
            Runtime.Marquee.Last_X := X_Frame;
            Runtime.Marquee.Last_Y := Y_Frame;
            Runtime.Marquee.Last_Scroll := Files.Model.Main_View_Scroll_Lines (Runtime.Model);
         end;
      end;
   end Update_Marquee_Drag;
