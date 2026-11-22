separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Overlay_Drop_Shadow
     (X        : Natural;
      Y        : Natural;
      Shadow_W : Natural;
      Shadow_H : Natural) is
   begin
      Guikit.Widgets.Draw_Drop_Shadow
        (Rectangles  => Result.Overlay_Rectangles,
         Clip_Width  => Layout.Width,
         Clip_Height => Layout.Height,
         X           => X,
         Y           => Y,
         Width       => Shadow_W,
         Height      => Shadow_H,
         Color       => Shadow_Color,
         Line_Height => Line_Height);
   end Add_Overlay_Drop_Shadow;
