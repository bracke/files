separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Input_Field
     (X            : Natural;
      Y            : Natural;
      Field_W      : Natural;
      Field_H      : Natural;
      Fill_Color   : Render_Color;
      Border_Color : Render_Color) is
   begin
      Guikit.Widgets.Draw_Input_Field
        (Rectangles   => Result.Rectangles,
         Clip_Width   => Layout.Width,
         Clip_Height  => Layout.Height,
         X            => X,
         Y            => Y,
         Width        => Field_W,
         Height       => Field_H,
         Fill_Color   => Fill_Color,
         Border_Color => Border_Color);
   end Add_Input_Field;
