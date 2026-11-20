with Files.Input_Actions;
--  The pointer gestures the window layer tracks across frames: a scrollbar
--  drag, a details column resize or reorder, and a marquee (rubber-band)
--  selection. Each is armed by its begin action and then updated once per
--  frame from the cursor and the left button, outside the model, until the
--  button is released or an overlay takes the input.
private package Files.Application.Windows.Gestures is

   --  Arm the gesture a begin action starts.
   --
   --  @param Runtime Window whose gesture state is armed.
   --  @param Action The click's input action.
   --  @param Armed True when Action began a gesture, which then needs no
   --  further dispatch; False leaves Runtime unchanged.
   procedure Arm
     (Runtime : in out Runtime_Window;
      Action  : Files.Input_Actions.Input_Action;
      Armed   : out Boolean);

   --  Advance every armed gesture by one frame, after cancelling them all
   --  while an input-owning overlay is open.
   --
   --  @param Runtime Window whose gestures move.
   --  @param Cursor_X Cursor X in window coordinates.
   --  @param Cursor_Y Cursor Y in window coordinates.
   --  @param Window_W Window width in screen coordinates.
   --  @param Window_H Window height in screen coordinates.
   --  @param Frame_W Framebuffer width in pixels.
   --  @param Frame_H Framebuffer height in pixels.
   --  @param Mouse_Down Whether the left button is held.
   procedure Update
     (Runtime    : in out Runtime_Window;
      Cursor_X   : Glfw.Input.Mouse.Coordinate;
      Cursor_Y   : Glfw.Input.Mouse.Coordinate;
      Window_W   : Glfw.Size;
      Window_H   : Glfw.Size;
      Frame_W    : Glfw.Size;
      Frame_H    : Glfw.Size;
      Mouse_Down : Boolean);

end Files.Application.Windows.Gestures;
