separate (Files.Application.Windows.Render_Window)
   procedure Read_Window_State is
   begin
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Width, Height);
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      --  The content scale is read once and again only after the window
      --  system reported a change (moved to another display, the desktop's
      --  scale changed), not on every pass.
      if not Runtime.Content_Read
        or else Glfw.Windows.Content_Scale.Changes /= Runtime.Scale_Changes_Seen
      then
         declare
            X_Scale, Y_Scale : Float;
         begin
            Runtime.Scale_Changes_Seen := Glfw.Windows.Content_Scale.Changes;
            Glfw.Windows.Content_Scale.Get (As_Window (Runtime.Handle), X_Scale, Y_Scale);
            Runtime.Content_Scale := Float'Max (X_Scale, Y_Scale);
            Runtime.Content_Read := True;
         end;
      end if;
      --  Text is drawn at the display's scale: the framebuffer's extra
      --  pixels (a Retina display, a scaled Wayland output) or, where it has
      --  none, the content scale (a Windows or X11 display at 150%).
      declare
         Ratio : constant Float :=
           Files.Application.Window_Policy.Display_Scale
             (Natural (Width), Natural (Window_W), Runtime.Content_Scale, Runtime.Pixel_Ratio);
      begin
         --  The one place the live size follows the settings: this window's
         --  scale changed, its own zoom or settings save changed the size, or
         --  another window's reached these settings (Share_Settings_From).
         --  The glyphs and the frame are rebuilt; the snapshot holds nothing
         --  sized by the font.
         if Ratio /= Runtime.Pixel_Ratio
           or else Scaled_Font_Size (Runtime) /= Runtime.Font_Pixel_Size
         then
            Runtime.Pixel_Ratio := Ratio;
            Runtime.Font_Pixel_Size := Scaled_Font_Size (Runtime);
            Files.Rendering.Text.Invalidate (Runtime.Text);
            Runtime.Frame_Cache_Valid := False;
         end if;
      end;
      Runtime.Handle.Drag_Scale :=
        Files.Application.Window_Policy.Window_Drag_Scale
          (Natural (Width), Natural (Window_W), Runtime.Pixel_Ratio);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);
      Mouse_Down :=
        Glfw.Windows.Mouse_Button_State (As_Window (Runtime.Handle), Glfw.Input.Mouse.Left_Button) =
        Glfw.Input.Pressed;

      Gestures.Update
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);
   end Read_Window_State;
