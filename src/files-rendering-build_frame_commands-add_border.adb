separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Border
     (X        : Natural;
      Y        : Natural;
      Border_W : Natural;
      Border_H : Natural;
      Color    : Render_Color) is
   begin
      Guikit.Widgets.Draw_Border
        (Result.Rectangles, Layout.Width, Layout.Height,
         X, Y, Border_W, Border_H, Color);
   end Add_Border;
