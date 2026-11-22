separate (Files.Rendering.Build_Frame_Commands)
   function Is_Pressed
     (X     : Natural;
      Y     : Natural;
      Box_W : Natural;
      Box_H : Natural;
      Live  : Boolean := False)
      return Boolean is
   begin
      --  Under the pointer, and where the press began: a drag (scrollbar,
      --  column, marquee) that crosses a button does not press it.
      return (Has_Press or else (Live and then Pointer.Pressed))
        and then Contains_Point (X, Y, Box_W, Box_H, Hover_X, Hover_Y)
        and then Contains_Point (X, Y, Box_W, Box_H, Press_X, Press_Y);
   end Is_Pressed;
