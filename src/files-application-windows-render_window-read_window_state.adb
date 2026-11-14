separate (Files.Application.Windows.Render_Window)
   procedure Read_Window_State is
   begin
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Width, Height);
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      --  Where the framebuffer has more pixels than the window (a Retina
      --  display, a scaled Wayland output), text is drawn that much larger.
      declare
         Ratio : constant Float :=
           Files.Window_Policy.Pixel_Ratio (Natural (Width), Natural (Window_W), Runtime.Pixel_Ratio);
      begin
         --  The size can move here two ways: this window's scale changed, or
         --  another window's zoom reached these settings through
         --  Share_Settings_From, which keeps no glyphs of its own.
         if Ratio /= Runtime.Pixel_Ratio
           or else Scaled_Font_Size (Runtime) /= Runtime.Font_Pixel_Size
         then
            Runtime.Pixel_Ratio := Ratio;
            Runtime.Font_Pixel_Size := Scaled_Font_Size (Runtime);
            Runtime.Text_Ready := False;
            Runtime.Glyph_Text_Valid := False;
            Runtime.Frame_Cache_Valid := False;
            Runtime.View.Snapshot_Valid := False;
         end if;
      end;
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);
      Mouse_Down :=
        Glfw.Windows.Mouse_Button_State (As_Window (Runtime.Handle), Glfw.Input.Mouse.Left_Button) =
        Glfw.Input.Pressed;

      Cancel_Background_Gestures_For_Overlay (Runtime);

      Update_Scrollbar_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);

      Update_Column_Resize_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Window_W   => Window_W,
         Frame_W    => Width,
         Mouse_Down => Mouse_Down);

      Update_Column_Reorder_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);

      Update_Marquee_Drag
        (Runtime    => Runtime,
         Cursor_X   => Cursor_X,
         Cursor_Y   => Cursor_Y,
         Window_W   => Window_W,
         Window_H   => Window_H,
         Frame_W    => Width,
         Frame_H    => Height,
         Mouse_Down => Mouse_Down);
   end Read_Window_State;
