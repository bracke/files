separate (Files.Application.Windows)
   procedure Handle_Pressed_Key
     (Runtime : in out Runtime_Window;
      Key     : Tracked_Key)
   is
      Pressed   : Boolean;
      Now       : Ada.Calendar.Time;
      Pending   : Natural;
      Fire_Count : Natural := 0;
   begin
      if Runtime.Handle = null then
         return;
      end if;

      --  Drain any press events the GLFW callback captured since last poll.
      --  This catches rapid press/release cycles that finish between frames.
      Pending := Runtime.Handle.Pending_Key_Presses (Key);
      Runtime.Handle.Pending_Key_Presses (Key) := 0;

      Pressed := Glfw.Windows.Key_State (As_Window (Runtime.Handle), To_Glfw_Key (Key)) = Glfw.Input.Pressed;
      if not Pressed then
         Runtime.Pressed_Keys (Key) := False;
         Fire_Count := Pending;
      else
         Now := Ada.Calendar.Clock;

         if not Runtime.Pressed_Keys (Key) then
            Runtime.Pressed_Keys (Key)   := True;
            Runtime.Key_Pressed_At (Key) := Now;
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := Natural'Max (Pending, 1);
         elsif Pending > 0 then
            --  Re-pressed without our seeing the release. Treat as fresh
            --  press(es) so the auto-repeat clock resets to the latest one.
            Runtime.Key_Pressed_At (Key) := Now;
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := Pending;
         elsif Key_Repeats (Key)
           and then Now - Runtime.Key_Pressed_At (Key) >= Key_Repeat_Initial_Delay
           and then Now - Runtime.Key_Last_Fired (Key) >= Key_Repeat_Interval
         then
            Runtime.Key_Last_Fired (Key) := Now;
            Fire_Count := 1;
         end if;
      end if;

      if Fire_Count = 0 then
         return;
      end if;

      --  Ctrl + Plus / Ctrl + Minus / Ctrl + 0 keyboard zoom now flows through
      --  the shared key seam (Files.Interaction.Handle_Key adjusts the font
      --  size in the settings model and reports Font_Size_Changed); the shell's
      --  Apply_Interaction_Result then syncs the live size and rebuilds glyphs.
      Refresh_Selection_Grid_Columns (Runtime);
      for I in 1 .. Fire_Count loop
         declare
            Result : Files.Interaction.Interaction_Result;
         begin
            --  Genuine live key dispatch flows through the testable seam: it
            --  runs the focus-aware controller and re-routes settings-path
            --  commands through Execute_Command. The follow-up (font-size sync,
            --  glyph rebuild, parallel character-event discard via
            --  Clear_Pending_Text) is applied here.
            Files.Interaction.Handle_Key
              (Model             => Runtime.Model,
               Settings          => Runtime.Settings,
               Settings_Path     => To_String (Runtime.Settings_Path),
               Key               => To_Key_Code (Key),
               Modifiers         => To_Modifiers (As_Window (Runtime.Handle)),
               Current_Font_Size => Runtime.Font_Pixel_Size,
               Result            => Result);
            Apply_Interaction_Result (Runtime, Result);
         end;
      end loop;
   end Handle_Pressed_Key;
