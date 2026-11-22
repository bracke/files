with Ada.Real_Time;
with Files.Environment;
with Files.Timing;
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

      --  A readback of a frame this scenario drew (Drawn_Before is the
      --  window's frame count when it started): the scenario's verdict, hash
      --  and region check, and the run's device and framebuffer facts.
      procedure Note_Frame
        (Runtime      : Runtime_Window;
         Scenario     : Live_Smoke_Scenario;
         Drawn_Before : Natural;
         Outcome      : in out Scenario_Outcome) is separate;

      --  The readback trails the frame it reads, and the run's first
      --  frames are the slowest: a scenario that ended before its
      --  own readback arrived was judged on none (hash 0, a blank
      --  verdict) -- or on the scenario before it -- and failed now
      --  and then. Only a readback of a frame this scenario drew
      --  counts, and the scenario renders on, up to a bound, until
      --  one arrives.
      procedure Render_Until_Readback (Scenario : Live_Smoke_Scenario; Outcome : in out Scenario_Outcome) is separate;

      --  The scenario's last frame held on screen for Hold seconds.
      procedure Hold_Frame (Scenario : Live_Smoke_Scenario) is
      begin
         if Hold > 0 then
            --  A fixed marker for tools to grep, like "live-smoke:", so
            --  built from space-free tokens rather than prose.
            Ada.Text_IO.Put_Line
              ("live-smoke" & ' ' & "hold" & ' ' & Live_Smoke_Scenario'Image (Scenario));
            Ada.Text_IO.Flush;
            for Tick in 1 .. Hold * 10 loop
               Guikit.Vulkan.Poll_Events;
               --  Answer a screen reader looking at the held frame.
               Files.Application.Accessibility.Service;
               delay 0.1;
            end loop;
         end if;
      end Hold_Frame;

      --  Render every scenario in order within the one window/device, taking
      --  each scenario's structural verdict and framebuffer hash from the
      --  final frame's readback.
      procedure Run_Scenarios (Bases : Scenario_Base_Vectors.Vector) is
      begin
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
               Render_Until_Readback (Scenario, Outcome);
               Result.Scenario_Results (Scenario) := Outcome;
               Hold_Frame (Scenario);
            end;
         end loop;
      end Run_Scenarios;

      --  Then the loop as the program runs it: back at the startup state, let
      --  the passes settle, press a key, and require that the passes drew the
      --  change -- the read-back frame differs from the settled one (with
      --  readback on, every pass submits a frame, so a count would not tell).
      --  A pass that raised every time after startup froze every window
      --  once; it is counted, and any count fails the smoke.
      procedure Check_Loop_Draws_Input (Bases : Scenario_Base_Vectors.Vector) is separate;

      --  Then a resize, which the scenarios above never make: the renderer
      --  rebuilds its swapchain for the new size while frames are still in
      --  flight. A frame drawn after the resize must be read back at the
      --  new framebuffer size.
      procedure Check_Resize is separate;
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
                  Settings => Runtime.Settings));
         end loop;

         Run_Scenarios (Bases);
         Check_Loop_Draws_Input (Bases);
         Check_Resize;
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
