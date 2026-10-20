separate (Files.Application.Windows)
   procedure Handle_Pressed_Key
     (Runtime : in out Runtime_Window;
      Key     : Tracked_Key)
   is
      Pressed   : Boolean;
      Now       : Ada.Calendar.Time;
      Pending   : Natural;
      Fire_Count : Natural := 0;

      function Tree_Page_Rows return Natural
      is
         Frame_W : Glfw.Size := 0;
         Frame_H : Glfw.Size := 0;
      begin
         if not Files.Model.Tree_Pick_Is_Active (Runtime.Model) then
            return 0;
         end if;

         Glfw.Windows.Get_Framebuffer_Size
           (As_Window (Runtime.Handle), Frame_W, Frame_H);
         if Frame_W = 0 or else Frame_H = 0 then
            return 0;
         end if;

         declare
            Line_Height : constant Positive :=
              Cell_Height_For (Runtime.Font_Pixel_Size);

            function Capacity_For
              (Snapshot : Files.Rendering.View_Snapshot)
               return Natural
            is
               Layout : constant Files.Rendering.Layout_Metrics :=
                 Files.Rendering.Calculate_Layout
                   (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
               Tree : constant Files.Rendering.Tree_Panel_Layout :=
                 Files.Rendering.Calculate_Tree_Panel_Layout
                   (Snapshot, Layout, Line_Height);
            begin
               return Files.Rendering.Tree_Row_Capacity (Snapshot, Tree);
            end Capacity_For;
         begin
            --  Key repeats arrive between frames; the last rendered snapshot
            --  is current unless the model or settings moved since, so reuse
            --  it rather than paying the O(items) rebuild on every keystroke.
            if Runtime.Frame_Cache_Valid
              and then Runtime.Cached_Model_Revision = Files.Model.Revision (Runtime.Model)
              and then Files.Settings.Same_Snapshot_Settings
                         (Runtime.Settings, Runtime.Cached_Settings_Key)
            then
               return Capacity_For (Runtime.Cached_Snapshot);
            end if;
            return Capacity_For
              (Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings));
         end;
      end Tree_Page_Rows;
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
               Result            => Result,
               Tree_Page_Rows    => Tree_Page_Rows);
            Apply_Interaction_Result (Runtime, Result);
         end;
      end loop;
   end Handle_Pressed_Key;
