separate (Files.Application.Windows)
   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
   is
      Action : Files.Events.Input_Action;
      Result : Files.Controller.Controller_Result;
      Offset : Integer;
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
   begin
      if Runtime.Handle = null or else Runtime.Handle.Pending_Scroll = 0 then
         return;
      end if;

      Offset := Runtime.Handle.Pending_Scroll;
      Runtime.Handle.Pending_Scroll := 0;

      --  Ctrl + scroll: live font-size adjustment (zoom in / out).
      declare
         Modifiers : constant Guikit.Input.Modifier_Set :=
           To_Modifiers (As_Window (Runtime.Handle));
      begin
         if Modifiers (Guikit.Input.Control_Key) then
            declare
               New_Size : constant Positive :=
                 Files.Settings.Clamp_Font_Pixel_Size
                   (Integer (Runtime.Font_Pixel_Size) + Offset);
            begin
               if New_Size /= Runtime.Font_Pixel_Size then
                  Runtime.Font_Pixel_Size := New_Size;
                  Runtime.Settings.Font_Pixel_Size := Runtime.Font_Pixel_Size;
                  Runtime.Text_Ready := False;
                  Runtime.Text_Glyph_Key := Null_Unbounded_String;
                  Persist_Settings (Runtime);
               end if;
            end;
            return;
         end if;
      end;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      if Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         Action := Files.Events.Translate_Scroll (Offset);
      else
         declare
            X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
         begin
            Action :=
              Files.Events.Translate_Scroll_At
                (Snapshot    => Snapshot,
                 X           => X,
                 Y           => Y,
                 Width       => Natural (Frame_W),
                 Height      => Natural (Frame_H),
                 Y_Offset    => Offset,
                 Line_Height => Cell_Height_For (Runtime.Font_Pixel_Size));
         end;
      end if;

      if Action.Kind = Files.Events.Scroll_Input_Action then
         Result :=
           Files.Controller.Handle_Targeted_Scroll
             (Runtime.Model, Action.Scroll_Area, Action.Scroll_Lines);
         pragma Unreferenced (Result);
      end if;
   end Handle_Scroll_Input;
