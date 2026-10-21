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
