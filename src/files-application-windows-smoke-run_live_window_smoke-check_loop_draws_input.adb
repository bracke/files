separate (Files.Application.Windows.Smoke.Run_Live_Window_Smoke)
   procedure Check_Loop_Draws_Input (Bases : Scenario_Base_Vectors.Vector) is
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
   end Check_Loop_Draws_Input;
