separate (Files.Application.Windows)
   overriding procedure Mouse_Scrolled
     (Object : not null access Desktop_Window;
      X      : Glfw.Input.Mouse.Scroll_Offset;
      Y      : Glfw.Input.Mouse.Scroll_Offset) is
      pragma Unreferenced (X);
   begin
      Object.Pending_Scroll :=
        Add_Pending_Scroll
          (Object.Pending_Scroll,
           Accumulate_Scroll_Offset (Object.Pending_Scroll_Remainder, Long_Float (Y)));
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Mouse_Scrolled;
