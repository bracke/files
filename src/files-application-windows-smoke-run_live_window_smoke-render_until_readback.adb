separate (Files.Application.Windows.Smoke.Run_Live_Window_Smoke)
   procedure Render_Until_Readback (Scenario : Live_Smoke_Scenario; Outcome : in out Scenario_Outcome) is
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
               Note_Frame (Runtime, Scenario, Drawn_Before (Window_Index), Outcome);
            end if;
            Window_Index := Window_Index + 1;
         end loop;
      end loop;
   end Render_Until_Readback;
