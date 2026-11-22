separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Focus_Ring
     (X      : Natural;
      Y      : Natural;
      Ring_W : Natural;
      Ring_H : Natural) is
   begin
      Guikit.Widgets.Draw_Focus_Ring
        (Rectangles  => Result.Rectangles,
         Clip_Width  => Layout.Width,
         Clip_Height => Layout.Height,
         X           => X,
         Y           => Y,
         Width       => Ring_W,
         Height      => Ring_H,
         Color       => Snapshot.Theme_Focus_Ring);
   end Add_Focus_Ring;
