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
         Snapshot    : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         Layout      : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout
             (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         Items       : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height);
         Rect_X      : Natural;
         Rect_Y      : Natural;
         Rect_W      : Natural;
         Rect_H      : Natural;
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
   end Update_Marquee_Drag;
