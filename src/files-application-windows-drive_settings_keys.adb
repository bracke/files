with Guikit.Settings_Panel;

separate (Files.Application.Windows)
   procedure Drive_Settings_Keys
     (Runtime     : in out Runtime_Window;
      Failed_Step : out Natural)
   is
      use type Guikit.Settings_Panel.Field_Kind;

      None       : constant Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Ctrl       : constant Guikit.Input.Modifier_Set :=
        [Guikit.Input.Control_Key => True, others => False];
      Shift      : constant Guikit.Input.Modifier_Set :=
        [Guikit.Input.Shift_Key => True, others => False];
      Ctrl_Shift : constant Guikit.Input.Modifier_Set :=
        [Guikit.Input.Control_Key | Guikit.Input.Shift_Key => True, others => False];

      Step : Natural := 0;

      --  Queue one press (and, like the platform, its own character when it
      --  types one), run the window's keyboard step, then render.
      procedure Press
        (Key       : Tracked_Key;
         Modifiers : Guikit.Input.Modifier_Set := None;
         Typed     : String := "") is
      begin
         Runtime.Handle.Pending_Input.Append
           (Input_Event'
              (Kind      => Key_Press_Event,
               Key       => Key,
               Physical  => To_Glfw_Key (Key),
               Modifiers => Modifiers,
               Text      => Null_Unbounded_String,
               Parallel  => False));
         if Typed /= "" then
            Runtime.Handle.Pending_Input.Append
              (Input_Event'
                 (Kind      => Text_Event,
                  Key       => Key,
                  Physical  => Glfw.Input.Keys.Unknown,
                  Modifiers => Modifiers,
                  Text      => To_Unbounded_String (Typed),
                  Parallel  => True));
         end if;
         Handle_Keyboard (Runtime);
         Render_Window (Runtime);
      end Press;

      --  A left click at a framebuffer position, as the window's click path
      --  handles one at the matching cursor position.
      procedure Click_At (X, Y : Natural) is
         Window_W, Window_H, Frame_W, Frame_H : Glfw.Size := 0;
      begin
         Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
         Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
         if Frame_W = 0 or else Frame_H = 0 then
            return;
         end if;
         Dispatch_Click_Action
           (Runtime,
            Current_Click_Action
              (Runtime, Window_W, Window_H, Frame_W, Frame_H,
               Glfw.Input.Mouse.Coordinate (Float (X) * Float (Window_W) / Float (Frame_W)),
               Glfw.Input.Mouse.Coordinate (Float (Y) * Float (Window_H) / Float (Frame_H)),
               Guikit.Input.No_Modifiers),
            Guikit.Input.No_Modifiers);
      end Click_At;

      --  Record the step; the first one whose expectation fails is reported.
      procedure Expect (Holds : Boolean) is
      begin
         Step := Step + 1;
         if not Holds and then Failed_Step = 0 then
            Failed_Step := Step;
         end if;
      end Expect;

      function Open return Boolean is
        (Files.Model.Settings_Pane_Is_Open (Runtime.Model)
         and then Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Settings_Input);

      function Key_Now return String is (Files.Model.Settings_Focused_Key (Runtime.Model));
   begin
      Failed_Step := 0;
      if Runtime.Handle = null then
         Failed_Step := 1;
         return;
      end if;

      Press (Tracked_Comma, Ctrl);
      Expect (Open);

      declare
         First : constant String := Key_Now;
      begin
         Press (Tracked_Down);
         Expect (Key_Now /= First);
         Press (Tracked_Up);
         Expect (Key_Now = First);
         Press (Tracked_Tab);
         Expect (Key_Now /= First);
         Press (Tracked_Tab, Shift);
         Expect (Key_Now = First);
      end;

      --  Walk to a toggle, flip it with Space (whose own space must not also
      --  be typed), then flip it back with Right.
      for Attempt in 1 .. 50 loop
         exit when Files.Model.Settings_Focused_Kind (Runtime.Model) = Guikit.Settings_Panel.Toggle;
         Press (Tracked_Tab);
      end loop;
      Expect (Files.Model.Settings_Focused_Kind (Runtime.Model) = Guikit.Settings_Panel.Toggle);
      declare
         Before : constant String := Files.Model.Settings_Focused_Value (Runtime.Model);
      begin
         Press (Tracked_Space, Typed => " ");
         Expect (Files.Model.Settings_Focused_Value (Runtime.Model) /= Before);
         --  The change applies without a save error: the smoke has no
         --  settings file, which turns persistence off rather than failing.
         Expect (Files.Model.Last_Error_Key (Runtime.Model) = "");
         Press (Tracked_Right);
         Expect (Files.Model.Settings_Focused_Value (Runtime.Model) = Before);

         --  The mouse: a click on the toggle's switch flips it, through the
         --  path a real click takes (window position -> input action ->
         --  dispatch). The switch sits at the focused row's right; sweep the
         --  row from that edge until the value changes.
         declare
            --  A copy: each click re-renders, which replaces the shown list.
            Shown   : constant Guikit.Draw.Accessibility_Node_Vectors.Vector := Runtime.Shown_Accessibility;
            Flipped : Boolean := False;
         begin
            for Node of Shown loop
               if Node.Focused and then Node.Width > 0 then
                  --  Clicks hit-test the last drawn layout, so no frame is
                  --  drawn between them; 4 px steps cannot miss a switch.
                  for Step in 0 .. Node.Width / 4 loop
                     exit when Node.Width < 4 * Step + 1;
                     Click_At (Node.X + Node.Width - 1 - 4 * Step, Node.Y + Node.Height / 2);
                     Flipped := Files.Model.Settings_Focused_Value (Runtime.Model) /= Before;
                     exit when Flipped;
                  end loop;
                  Render_Window (Runtime);
                  exit;
               end if;
            end loop;
            Expect (Flipped);
         end;
      end;

      Press (Tracked_Tab, Ctrl);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 2);
      Press (Tracked_Tab, Ctrl_Shift);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 1);

      Press (Tracked_Escape);
      Expect (not Files.Model.Settings_Pane_Is_Open (Runtime.Model)
              and then Files.Model.Focus (Runtime.Model) = Files.Types.Focus_None);

      --  Reopen and leave it on the second tab, so the final frame shows the
      --  panel the keys drove rather than the startup view.
      Press (Tracked_Comma, Ctrl);
      Expect (Open);
      Press (Tracked_Tab, Ctrl);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 2);
   end Drive_Settings_Keys;
