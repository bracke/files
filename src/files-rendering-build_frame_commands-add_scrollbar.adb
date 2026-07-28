separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Scrollbar
     (Track_X  : Natural;
      Track_Y  : Natural;
      Track_W  : Natural;
      Track_H  : Natural;
      Thumb_Y  : Natural;
      Thumb_H  : Natural) is
   begin
      Guikit.Widgets.Draw_Scrollbar
        (Rectangles   => Result.Rectangles,
         Clip_Width   => Layout.Width,
         Clip_Height  => Layout.Height,
         Track_X      => Track_X,
         Track_Y      => Track_Y,
         Track_Width  => Track_W,
         Track_Height => Track_H,
         Thumb_Y      => Thumb_Y,
         Thumb_Height => Thumb_H,
         Track_Color  => Border_Color,
         Thumb_Color  => Selection_Color,
         Grip_Color   => Muted_Text_Color);
   end Add_Scrollbar;
