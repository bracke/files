separate (Files.Application.Windows.Smoke.Run_Live_Window_Smoke)
   procedure Check_Resize is
      Window          : Runtime_Window renames Runtime_Windows (1);
      --  How long the resize may take to reach the screen: by time,
      --  not by a count of passes, which a slow runner (software
      --  Vulkan) spends before the swapchain is rebuilt and a fast one
      --  in a moment.
      Resize_Limit    : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Seconds (10);
      Resize_Started  : Ada.Real_Time.Time;
      Width, Height   : Glfw.Size;
      Old_Frame_Width : Glfw.Size;
      Old_Frame_Height : Glfw.Size;
      Frame_Width     : Glfw.Size;
      Frame_Height    : Glfw.Size;
      Submitted       : Natural;
   begin
      Glfw.Windows.Get_Size (As_Window (Window.Handle), Width, Height);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Window.Handle), Old_Frame_Width, Old_Frame_Height);
      Glfw.Windows.Set_Size (As_Window (Window.Handle), Width - Width / 4, Height - Height / 4);
      Submitted := Guikit.Vulkan.Diagnostics (Window.Vulkan).Submitted_Frames;
      Resize_Started := Ada.Real_Time.Clock;
      loop
         Guikit.Vulkan.Poll_Events;
         Event_Loop_Pass (Runtime_Windows, Loop_State);
         Glfw.Windows.Get_Framebuffer_Size (As_Window (Window.Handle), Frame_Width, Frame_Height);
         declare
            Drawn : constant Guikit.Vulkan.Renderer_Diagnostics := Guikit.Vulkan.Diagnostics (Window.Vulkan);
         begin
            Result.Resize_Drawn :=
              (Frame_Width /= Old_Frame_Width or else Frame_Height /= Old_Frame_Height)
              and then Drawn.Last_Framebuffer_Frame > Submitted
              and then Drawn.Frame_Width = Natural (Frame_Width)
              and then Drawn.Frame_Height = Natural (Frame_Height);
         end;
         exit when Result.Resize_Drawn
           or else Files.Timing.Elapsed (Ada.Real_Time.Clock, Resize_Started, Resize_Limit);
         delay 0.01;
      end loop;
   end Check_Resize;
