separate (Files.Rendering.Build_Frame_Commands)
   procedure Append_Rect
     (Target : in out Rectangle_Command_Vectors.Vector;
      X      : Natural;
      Y      : Natural;
      Rect_W : Natural;
      Rect_H : Natural;
      Color  : Render_Color)
   is
      Draw_W : constant Natural := Clipped_Size (X, Rect_W, Layout.Width);
      Draw_H : constant Natural := Clipped_Size (Y, Rect_H, Layout.Height);
   begin
      if Draw_W > 0 and then Draw_H > 0 then
         Target.Append
           (Rectangle_Command'(X => X, Y => Y, Width => Draw_W, Height => Draw_H, Color => Color));
      end if;
   end Append_Rect;
