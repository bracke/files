separate (Files.Application.Windows)
   function Hit_Position_At
     (Runtime  : in out Runtime_Window;
      Window_W : Glfw.Size;
      Window_H : Glfw.Size;
      Frame_W  : Glfw.Size;
      Frame_H  : Glfw.Size;
      Cursor_X : Glfw.Input.Mouse.Coordinate;
      Cursor_Y : Glfw.Input.Mouse.Coordinate)
      return Hit_Position is
   begin
      if not Files.Application.Window_Policy.Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H)
        or else Frame_W <= 0 or else Frame_H <= 0
      then
         return (others => <>);
      end if;
      declare
         --  Before the first frame this refreshes Runtime's snapshot.
         Slot : constant Snapshot_Slot := Hit_Slot (Runtime);
      begin
         return
           (Inside      => True,
            X           => Files.Application.Window_Policy.Scale_X (Cursor_X, Window_W, Frame_W),
            Y           => Files.Application.Window_Policy.Scale_Coordinate (Cursor_Y, Window_H, Frame_H),
            Width       => Natural (Frame_W),
            Height      => Natural (Frame_H),
            Line_Height => Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size),
            Slot        => Slot);
      end;
   end Hit_Position_At;
