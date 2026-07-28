separate (Files.Application.Windows)
   function Run_Live_Window_Smoke
     (Startup : Startup_Result;
      Plan    : Live_Smoke_Plan)
      return Live_Smoke_Result
   is
      Runtime_Windows : Runtime_Window_Vectors.Vector;
      Initialized     : Boolean := False;
      Result          : Live_Smoke_Result := Evaluate_Live_Window_Smoke (Plan);
   begin
      if not Plan.Can_Run or else Startup.Windows.Is_Empty then
         if Startup.Windows.Is_Empty then
            Result.Error_Key := To_Unbounded_String ("runtime.smoke.no_windows");
         end if;
         return Result;
      end if;

      Result.Attempted := True;
      Result.Skipped_By_Plan := False;
      Glfw.Init;
      Initialized := True;
      Guikit.Vulkan.Configure_Window_Hints;

      for Startup_Window of Startup.Windows loop
         Append_Runtime_Window
           (Runtime_Windows => Runtime_Windows,
            Startup_Window  => Startup_Window,
            Settings        => Startup.Settings,
            Settings_Path   => Startup.Settings_Path,
            Width           => Plan.Width,
            Height          => Plan.Height);
      end loop;
      for Runtime of Runtime_Windows loop
         Guikit.Vulkan.Set_Readback_Enabled (Runtime.Vulkan, True);
      end loop;

      Result.Window_Created := not Runtime_Windows.Is_Empty;
      for Poll_Index in 1 .. Plan.Input_Poll_Count loop
         Guikit.Vulkan.Poll_Events;
         Handle_All_Keyboard (Runtime_Windows);
         Handle_All_Text_Input (Runtime_Windows);
         Handle_All_Mouse (Runtime_Windows);
         Handle_All_Drop_Input (Runtime_Windows);
         Handle_All_Scroll_Input (Runtime_Windows);
         Handle_All_File_Watch_Poll (Runtime_Windows);
         Result.Input_Polled := True;
      end loop;

      --  Capture the pristine per-window baseline so each scenario starts from
      --  the same startup state and any framebuffer difference is caused by the
      --  scenario alone.
      declare
         Bases : Scenario_Base_Vectors.Vector;
      begin
         for Runtime of Runtime_Windows loop
            --  Seed a full synthetic grid when the real startup directory is too
            --  sparse to fill the frame, so the plain-view scenarios (default,
            --  selection, light theme) pass the "every band has content"
            --  structural check regardless of the user's home directory.
            if Files.Model.Visible_Count (Runtime.Model) < Scenario_Minimum_Fill_Items then
               Files.Model.Replace_Items
                 (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
            end if;
            Bases.Append
              (Scenario_Base_State'
                 (Model    => Runtime.Model,
                  Settings => Runtime.Settings,
                  Font     => Runtime.Font_Pixel_Size));
         end loop;

         --  Render every scenario in order within the one window/device, taking
         --  each scenario's structural verdict and framebuffer hash from the
         --  final frame's readback.
         for Scenario in Live_Smoke_Scenario loop
            declare
               Base_Index : Positive := 1;
               Outcome    : Scenario_Outcome := (others => <>);
            begin
               for Runtime of Runtime_Windows loop
                  Prepare_Scenario (Runtime, Bases (Base_Index), Scenario);
                  Base_Index := Base_Index + 1;
               end loop;

               for Frame_Index in 1 .. Plan.Frame_Count loop
                  Result.Frames_Attempted := Result.Frames_Attempted + 1;
                  Render_All (Runtime_Windows);
                  Result.Frame_Rendered :=
                    Result.Frame_Rendered or else Any_Runtime_Frame_Rendered (Runtime_Windows);
                  for Runtime of Runtime_Windows loop
                     if Runtime.Last_Present_Status /= Guikit.Vulkan.Vulkan_Not_Initialized then
                        declare
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
                           if Diagnostics.Framebuffer_Readback_Ready then
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
                        end;
                     end if;
                  end loop;
               end loop;

               Result.Scenario_Results (Scenario) := Outcome;
            end;
         end loop;
      end;

      --  Overall structural verdict: every scenario must pass and every
      --  non-default scenario's frame must differ from the default frame.
      Result.Framebuffer_Passed := Scenarios_Verdict (Result.Scenario_Results);

      Release_All (Runtime_Windows);
      Glfw.Shutdown;
      Result.Closed_Cleanly := True;
      Result.Error_Key :=
        To_Unbounded_String
          ((if Result.Frame_Rendered then "runtime.smoke.ready" else "runtime.smoke.text_failed"));
      return Result;
   exception
      when Desktop_Error =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         return
           (Attempted       => True,
            Window_Created  => Result.Window_Created,
            Frame_Rendered  => Result.Frame_Rendered,
            Frames_Attempted => Result.Frames_Attempted,
            Frames_Presented => Result.Frames_Presented,
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
            Last_Status     => Result.Last_Status,
            Last_Vk_Result  => Result.Last_Vk_Result,
            Framebuffer_Readback_Ready => Result.Framebuffer_Readback_Ready,
            Last_Framebuffer_Hash => Result.Last_Framebuffer_Hash,
            Last_Framebuffer_Bytes => Result.Last_Framebuffer_Bytes,
            Framebuffer_Analysis => Result.Framebuffer_Analysis,
            Framebuffer_Passed => Result.Framebuffer_Passed,
            Vulkan_Device_Ready => Result.Vulkan_Device_Ready,
            Scenario_Results => Result.Scenario_Results,
            Error_Key       => To_Unbounded_String ("error.window.create"));
      when others =>
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         return
           (Attempted       => True,
            Window_Created  => Result.Window_Created,
            Frame_Rendered  => Result.Frame_Rendered,
            Frames_Attempted => Result.Frames_Attempted,
            Frames_Presented => Result.Frames_Presented,
            Input_Polled    => Result.Input_Polled,
            Closed_Cleanly  => False,
            Skipped_By_Plan => False,
            Last_Status     => Result.Last_Status,
            Last_Vk_Result  => Result.Last_Vk_Result,
            Framebuffer_Readback_Ready => Result.Framebuffer_Readback_Ready,
            Last_Framebuffer_Hash => Result.Last_Framebuffer_Hash,
            Last_Framebuffer_Bytes => Result.Last_Framebuffer_Bytes,
            Framebuffer_Analysis => Result.Framebuffer_Analysis,
            Framebuffer_Passed => Result.Framebuffer_Passed,
            Vulkan_Device_Ready => Result.Vulkan_Device_Ready,
            Scenario_Results => Result.Scenario_Results,
            Error_Key       => To_Unbounded_String ("error.window.create"));
   end Run_Live_Window_Smoke;
