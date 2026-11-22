separate (Files.Application.Windows)
   overriding procedure Mouse_Position_Changed
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Coordinate;
      Y      : Glfw.Input.Mouse.Coordinate)
   is
   begin
      Object.Last_Mouse_X := X;
      Object.Last_Mouse_Y := Y;

      --  Worked out inside the handler: what an initial value raises would
      --  escape it into GLFW.
      --  Window coordinates: the drag distance is scaled to them.
      if Object.Left_Mouse_Down
        and then Files.Application.Window_Policy.Is_Drag
                   (Long_Float (X - Object.Drag_Start_X), Long_Float (Y - Object.Drag_Start_Y), Object.Drag_Scale)
      then
         Object.Drag_Moved := True;
      end if;
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Mouse_Position_Changed;
