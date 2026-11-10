with Files.Environment;
with Files.Diagnostics;
with Ada.Text_IO;

separate (Files.Application.Windows.Smoke)
   function Run_Live_Window_Smoke
     (Startup : Startup_Result;
      Plan    : Live_Smoke_Plan)
      return Live_Smoke_Result
   is
      Runtime_Windows : Runtime_Window_Vectors.Vector;
      Initialized     : Boolean := False;
      Result          : Live_Smoke_Result := Evaluate_Live_Window_Smoke (Plan);
      Loop_State      : Event_Loop_State;

      --  FILES_LIVE_SMOKE_HOLD=<seconds> keeps each scenario's last frame on
      --  screen that long, announced on standard output, so a person or a
      --  screenshot tool can look at it. Unset or invalid: no pause.
      function Hold_Seconds return Natural is
         Value : constant String := Files.Environment.Value ("FILES_LIVE_SMOKE_HOLD");
      begin
         return (if Value = "" then 0 else Natural'Min (Natural'Value (Value), 600));
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Application.Windows.Smoke");
            return 0;
      end Hold_Seconds;

      Hold : constant Natural := Hold_Seconds;

      --  Extra frames a scenario may take for its readback to arrive.
      Max_Readback_Wait_Frames : constant := 30;
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
            --  A smoke run drives scripted windows at the plan's size; it
            --  must not persist that size (or anything else) to the user's file.
            Settings_Path   => Null_Unbounded_String,
            Width           => Plan.Width,
            Height          => Plan.Height);
      end loop;
      for Runtime of Runtime_Windows loop
         Guikit.Vulkan.Set_Readback_Enabled (Runtime.Vulkan, True);
      end loop;

      Result.Window_Created := not Runtime_Windows.Is_Empty;
      --  The program's own loop pass, not a list of its steps.
      for Poll_Index in 1 .. Plan.Input_Poll_Count loop
         Guikit.Vulkan.Poll_Events;
         Event_Loop_Pass (Runtime_Windows, Loop_State);
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

               if Scenario = Scenario_Settings_Keyboard then
                  Outcome.Keys_Checked := True;
                  Drive_Settings_Keys (Runtime_Windows (1), Outcome.Keys_Failed_Step);
               end if;

               --  The readback trails the frame it reads, and the run's first
               --  frames are the slowest: a scenario that ended before its
               --  own readback arrived was judged on none (hash 0, a blank
               --  verdict) -- or on the scenario before it -- and failed now
               --  and then. Only a readback of a frame this scenario drew
               --  counts, and the scenario renders on, up to a bound, until
               --  one arrives.
               declare
                  Drawn_Before : array (1 .. Natural (Runtime_Windows.Length)) of Natural := [others => 0];
                  Window_Index : Positive := 1;
               begin
                  for Runtime of Runtime_Windows loop
                     Drawn_Before (Window_Index) := Guikit.Vulkan.Diagnostics (Runtime.Vulkan).Submitted_Frames;
                     Window_Index := Window_Index + 1;
                  end loop;
                  for Frame_Index in 1 .. Plan.Frame_Count + Max_Readback_Wait_Frames loop
                     exit when Frame_Index > Plan.Frame_Count and then Outcome.Readback_Ready;
                     Result.Frames_Attempted := Result.Frames_Attempted + 1;
                     --  Render directly rather than through Render_All, whose
                     --  per-window boundary would hide a failing frame from the smoke.
                     for Runtime of Runtime_Windows loop
                        Render_Window (Runtime);
                     end loop;
                     Result.Frame_Rendered :=
                       Result.Frame_Rendered or else Any_Runtime_Frame_Rendered (Runtime_Windows);
                     Window_Index := 1;
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
                              if Diagnostics.Framebuffer_Readback_Ready
                                and then Diagnostics.Last_Framebuffer_Frame > Drawn_Before (Window_Index)
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
                           end;
                        end if;
                        Window_Index := Window_Index + 1;
                     end loop;
                  end loop;
               end;

               Result.Scenario_Results (Scenario) := Outcome;
               if Hold > 0 then
                  --  A fixed marker for tools to grep, like "live-smoke:", so
                  --  built from space-free tokens rather than prose.
                  Ada.Text_IO.Put_Line
                    ("live-smoke" & ' ' & "hold" & ' ' & Live_Smoke_Scenario'Image (Scenario));
                  Ada.Text_IO.Flush;
                  for Tick in 1 .. Hold * 10 loop
                     Guikit.Vulkan.Poll_Events;
                     --  Answer a screen reader looking at the held frame.
                     Files.Accessibility.Service;
                     delay 0.1;
                  end loop;
               end if;
            end;
         end loop;

         --  Then the loop as the program runs it: back at the startup state, let
         --  the passes settle, press a key, and require that the passes drew the
         --  change -- the read-back frame differs from the settled one (with
         --  readback on, every pass submits a frame, so a count would not tell).
         --  A pass that raised every time after startup froze every window
         --  once; it is counted, and any count fails the smoke.
         declare
            Window : Runtime_Window renames Runtime_Windows (1);
            Settle_Passes : constant := 10;
            Before : Interfaces.Unsigned_32;
         begin
            Prepare_Scenario (Window, Bases (1), Scenario_Default);
            for Pass in 1 .. Settle_Passes loop
               Guikit.Vulkan.Poll_Events;
               Event_Loop_Pass (Runtime_Windows, Loop_State);
            end loop;
            Before := Guikit.Vulkan.Diagnostics (Window.Vulkan).Last_Framebuffer_Hash;
            --  Ctrl+= (zoom in): it redraws everything and starts no
            --  background work. Selecting an item would measure a folder of
            --  the runner's home, whose helper may outlive the smoke's exit.
            Window.Handle.Pending_Input.Append
              (Input_Event'
                 (Kind      => Key_Press_Event,
                  Key       => Guikit.Input.Key_Equal,
                  Modifiers => [Guikit.Input.Control_Key => True, others => False],
                  Text      => Null_Unbounded_String,
                  Parallel  => False));
            for Pass in 1 .. Settle_Passes loop
               Guikit.Vulkan.Poll_Events;
               Event_Loop_Pass (Runtime_Windows, Loop_State);
               Result.Loop_Drew_Input :=
                 Guikit.Vulkan.Diagnostics (Window.Vulkan).Last_Framebuffer_Hash /= Before;
               exit when Result.Loop_Drew_Input;
            end loop;
         end;
      end;

      --  Overall structural verdict: every scenario must pass and every
      --  non-default scenario's frame must differ from the default frame.
      Result.Framebuffer_Passed := Scenarios_Verdict (Result.Scenario_Results);

      Result.Loop_Failures := Files.Diagnostics.Event_Loop_Failures;

      Release_All (Runtime_Windows);
      Glfw.Shutdown;
      Result.Closed_Cleanly := True;
      Result.Error_Key :=
        To_Unbounded_String
          ((if Result.Frame_Rendered then "runtime.smoke.ready" else "runtime.smoke.text_failed"));
      return Result;
   exception
      --  Whatever the run reached, as it was; only the close failed.
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Application.Windows.Smoke");
         Release_All (Runtime_Windows);
         if Initialized then
            Glfw.Shutdown;
         end if;
         Result.Attempted := True;
         Result.Skipped_By_Plan := False;
         Result.Closed_Cleanly := False;
         Result.Loop_Failures := Files.Diagnostics.Event_Loop_Failures;
         Result.Error_Key := To_Unbounded_String ("error.window.create");
         return Result;
   end Run_Live_Window_Smoke;
