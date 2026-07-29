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
      if not Runtime.Marquee_Active then
         return;
      elsif Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Runtime.Marquee_Active := False;
         return;
      end if;

      X_Frame := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
      Y_Frame := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);

      if not Mouse_Down then
         --  Released: end the gesture and stop drawing the rectangle, keeping
         --  whatever selection the drag produced. A press that never crossed the
         --  threshold left the selection untouched, so an empty-space click that
         --  did not drag stays a no-op.
         Runtime.Marquee_Active := False;
         Runtime.Marquee_Rect_W := 0;
         Runtime.Marquee_Rect_H := 0;
         return;
      end if;

      if not Runtime.Marquee_Moved then
         if abs (X_Frame - Runtime.Marquee_Origin_X) > Marquee_Drag_Threshold
           or else abs (Y_Frame - Runtime.Marquee_Origin_Y) > Marquee_Drag_Threshold
         then
            Runtime.Marquee_Moved := True;
         else
            return;
         end if;
      end if;

      declare
         Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);

         Snapshot  : Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout    : Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Main_View : Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
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
                        Files.Model.Set_Main_View_Scroll_Lines (Runtime.Model, New_Lines);
                        --  Rebuild against the new scroll, then re-anchor the
                        --  origin by the scroll's actual pixel shift (which the
                        --  renderer may snap to a row period, so measure it).
                        Snapshot := Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
                        Layout := Files.Rendering.Calculate_Layout
                          (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
                        Main_View :=
                          Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line_Height);
                        Runtime.Marquee_Origin_Y :=
                          Runtime.Marquee_Origin_Y
                          - (Integer (Main_View.Scroll_Pixels) - Integer (Old_Px));
                     end if;
                  end;
               end if;
            end;
         end if;

         declare
            Items  : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
            Rect_X : Natural;
            Rect_Y : Natural;
            Rect_W : Natural;
            Rect_H : Natural;
         begin
            Files.Rendering.Marquee_Rect
              (Start_X   => Natural'Max (0, Runtime.Marquee_Origin_X),
               Start_Y   => Natural'Max (0, Runtime.Marquee_Origin_Y),
               Current_X => Natural'Max (0, X_Frame),
               Current_Y => Natural'Max (0, Y_Frame),
               X         => Rect_X,
               Y         => Rect_Y,
               Width     => Rect_W,
               Height    => Rect_H);
            Files.Interaction.Apply_Marquee_Selection
              (Model    => Runtime.Model,
               Hits     =>
                 Files.Rendering.Items_In_Rect (Items, Rect_X, Rect_Y, Rect_W, Rect_H),
               Additive => Runtime.Marquee_Additive,
               Base     => Runtime.Marquee_Base);
            Runtime.Marquee_Rect_X := Rect_X;
            Runtime.Marquee_Rect_Y := Rect_Y;
            Runtime.Marquee_Rect_W := Rect_W;
            Runtime.Marquee_Rect_H := Rect_H;
         end;
      end;
   end Update_Marquee_Drag;
