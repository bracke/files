separate (Files.Application.Windows)
   procedure Handle_Scroll_Input
     (Runtime : in out Runtime_Window)
   is
      Action : Files.Events.Input_Action;
      Result : Files.Interaction.Interaction_Result;
      Offset : Integer;
      Window_W : Glfw.Size := 0;
      Window_H : Glfw.Size := 0;
      Frame_W  : Glfw.Size := 0;
      Frame_H  : Glfw.Size := 0;
      Cursor_X : Glfw.Input.Mouse.Coordinate := 0.0;
      Cursor_Y : Glfw.Input.Mouse.Coordinate := 0.0;
   begin
      Save_Pending_Zoom (Runtime, Force => False);
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
            --  Modal overlays own wheel input just as they own ordinary key,
            --  click, drop, and scroll events. Consume Ctrl+wheel without
            --  changing persisted UI state while any such overlay is open.
            if not Files.Model.Input_Owning_Overlay_Is_Open (Runtime.Model) then
               declare
                  Zoomed : Files.Interaction.Interaction_Result;
               begin
                  --  In memory now (no settings path), saved when the wheel
                  --  rests: see Save_Pending_Zoom.
                  Files.Interaction.Apply_Zoom
                    (Runtime.Model, Runtime.Settings, "",
                     Files.Settings.Clamp_Font_Pixel_Size
                       (Add_Pending_Scroll (Integer (Runtime.Settings.Font_Pixel_Size), Offset)),
                     Zoomed);
                  if Zoomed.Settings_Changed then
                     Runtime.Zoom_Unsaved := True;
                     Runtime.Zoom_At := Ada.Real_Time.Clock;
                  end if;
                  Apply_Interaction_Result (Runtime, Zoomed);
               end;
            end if;
            return;
         end if;
      end;

      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      Glfw.Windows.Get_Cursor_Pos (As_Window (Runtime.Handle), Cursor_X, Cursor_Y);

      if Window_W = 0 or else Window_H = 0 or else Frame_W = 0 or else Frame_H = 0 then
         --  Without viewport geometry there is no meaningful scroll target or
         --  maximum offset. Discard the event instead of accumulating invisible
         --  main/info offsets while the window is minimized.
         Action := (Kind => Files.Events.No_Input_Action);
      elsif not Cursor_Is_Inside_Window (Cursor_X, Cursor_Y, Window_W, Window_H) then
         Action := (Kind => Files.Events.No_Input_Action);
      else
         Refresh_Snapshot (Runtime);
         declare
            X        : constant Natural := Scale_Coordinate (Cursor_X, Window_W, Frame_W);
            Y        : constant Natural := Scale_Coordinate (Cursor_Y, Window_H, Frame_H);
            Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Current_Slot);
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

      --  Dispatched like every other input, so the scroll gets the same
      --  follow-ups.
      if Action.Kind = Files.Events.Scroll_Input_Action then
         Files.Interaction.Apply_Input_Action
           (Model             => Runtime.Model,
            Settings          => Runtime.Settings,
            Settings_Path     => To_String (Runtime.Settings_Path),
            Action            => Action,
            Modifiers         => To_Modifiers (As_Window (Runtime.Handle)),
            Result            => Result);
         Apply_Interaction_Result (Runtime, Result);
      end if;
   end Handle_Scroll_Input;
