separate (Files.Application.Windows.Smoke.Run_Live_Window_Smoke)
   procedure Note_Frame
     (Runtime      : Runtime_Window;
      Scenario     : Live_Smoke_Scenario;
      Drawn_Before : Natural;
      Outcome      : in out Scenario_Outcome)
   is
      Diagnostics : constant Guikit.Vulkan.Renderer_Diagnostics :=
        Guikit.Vulkan.Diagnostics (Runtime.Vulkan);
   begin
      Result.Last_Status := Runtime.Last_Present_Status;
      Result.Last_Vk_Result := Diagnostics.Last_Vk_Result;
      Result.Vulkan_Device_Ready :=
        Result.Vulkan_Device_Ready or else Diagnostics.Device_Ready;
      if Runtime.Last_Present_Status = Guikit.Vulkan.Vulkan_Presented then
         Result.Frames_Presented := Result.Frames_Presented + 1;
      end if;
      if Diagnostics.Framebuffer_Readback_Ready
        and then Diagnostics.Last_Framebuffer_Frame > Drawn_Before
      then
         Result.Framebuffer_Readback_Ready := True;
         Result.Last_Framebuffer_Bytes := Diagnostics.Last_Framebuffer_Bytes;
         Outcome.Rendered := True;
         Outcome.Readback_Ready := True;
         Outcome.Hash := Diagnostics.Last_Framebuffer_Hash;
         Outcome.Passed := Diagnostics.Framebuffer_Passed;

         --  Layout-derived region assertion: prove a
         --  specific UI element rendered at the pixel
         --  rectangle its layout computed. An empty region
         --  where the structural Analyze still passed is
         --  exactly what a coordinate/DPI-scaling
         --  regression produces, so it fails the scenario.
         declare
            Rect : constant Region_Rect :=
              Scenario_Region
                (Runtime, Scenario,
                 Diagnostics.Frame_Width, Diagnostics.Frame_Height);
         begin
            if Rect.Valid then
               Outcome.Region_Checked := True;
               Outcome.Region_Ink_Fraction :=
                 Guikit.Vulkan.Readback_Region_Ink_Fraction
                   (Runtime.Vulkan, Rect.X, Rect.Y, Rect.W, Rect.H);
               Outcome.Region_Ink_Present :=
                 Guikit.Vulkan.Readback_Region_Has_Ink
                   (Runtime.Vulkan, Rect.X, Rect.Y, Rect.W, Rect.H);
            end if;
         end;

         --  The default scenario feeds the legacy
         --  single-frame diagnostics printout.
         if Scenario = Scenario_Default then
            Result.Last_Framebuffer_Hash := Diagnostics.Last_Framebuffer_Hash;
            Result.Framebuffer_Analysis := Diagnostics.Framebuffer_Analysis;
         end if;
      end if;
   end Note_Frame;
