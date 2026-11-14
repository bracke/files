separate (Files.Application.Windows)
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
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Mouse_Position_Changed;
