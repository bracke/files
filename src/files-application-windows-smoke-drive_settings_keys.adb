with Files.Preference_Types;
with Files.IO.Fs_Primitives;
with Guikit.Settings_Panel;
with Hostkit.Fs;
with Files.Model.Settings_Pane;
with Files.Rendering.Layouts;

separate (Files.Application.Windows.Smoke)
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
        (Key       : Guikit.Input.Key_Code;
         Modifiers : Guikit.Input.Modifier_Set := None;
         Typed     : String := "") is separate;

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
        (Files.Model.Settings_Pane.Is_Open (Runtime.Model)
         and then Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_Settings_Input);

      function Key_Now return String is (Files.Model.Settings_Pane.Focused_Key (Runtime.Model));

      --  Down/Up and Tab/Shift+Tab move the focus between fields and back.
      procedure Check_Field_Keys is
         First : constant String := Key_Now;
      begin
         Press (Guikit.Input.Key_Down);
         Expect (Key_Now /= First);
         Press (Guikit.Input.Key_Up);
         Expect (Key_Now = First);
         Press (Guikit.Input.Key_Tab);
         Expect (Key_Now /= First);
         Press (Guikit.Input.Key_Tab, Shift);
         Expect (Key_Now = First);
      end Check_Field_Keys;

      --  The mouse: a click on the toggle's switch flips it, through the
      --  path a real click takes (window position -> input action ->
      --  dispatch). The switch sits at the focused row's right; sweep the
      --  row from that edge until the value changes.
      procedure Click_Toggle_Switch (Before : String) is separate;

      --  A screen reader's "activate" on the focused toggle flips it too,
      --  through the path its requests take (a click on the node's
      --  centre, which only focuses a settings row, then its change).
      procedure Activate_Toggle is
         Shown  : constant Guikit.Draw.Accessibility_Node_Vectors.Vector := Runtime.Shown_Frame.Accessibility;
         Was    : constant String := Files.Model.Settings_Pane.Focused_Value (Runtime.Model);
         Asked  : Boolean := False;
      begin
         for Node of Shown loop
            if Node.Focused and then Node.Width > 0 then
               Perform_Accessibility_Request
                 (Runtime,
                  (Kind   => A11ykit.Provider.Activate_Request,
                   Node   => 0,
                   Bounds => (X => Node.X, Y => Node.Y, Width => Node.Width, Height => Node.Height)));
               Render_Window (Runtime);
               Asked := True;
               exit;
            end if;
         end loop;
         Expect (Asked and then Files.Model.Settings_Pane.Focused_Value (Runtime.Model) /= Was);
      end Activate_Toggle;

      --  Walk to a toggle, flip it with Space (whose own space must not also
      --  be typed), then flip it back with Right.
      procedure Check_Toggle is separate;

      --  Ctrl+Tab and Ctrl+Shift+Tab switch sections; Escape closes the pane.
      procedure Check_Sections_And_Close is
      begin
         Press (Guikit.Input.Key_Tab, Ctrl);
         Expect (Files.Model.Settings_Pane.Active_Section (Runtime.Model) = 2);
         Press (Guikit.Input.Key_Tab, Ctrl_Shift);
         Expect (Files.Model.Settings_Pane.Active_Section (Runtime.Model) = 1);

         Press (Guikit.Input.Key_Escape);
         Expect (not Files.Model.Settings_Pane.Is_Open (Runtime.Model)
                 and then Files.Model.Focus (Runtime.Model) = Files.UI_Types.Focus_None);
      end Check_Sections_And_Close;

      function Selected_Shown return Boolean is
         Frame_W, Frame_H : Glfw.Size := 0;
         Line_Height : constant Positive := Files.Rendering.Cell_Height_For (Runtime.Font_Pixel_Size);
      begin
         Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
            Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Layouts.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
         begin
            for Cell of Files.Rendering.Layouts.Calculate_Item_Layout (Snapshot, Layout, Line_Height) loop
               if Cell.Visible_Index = Files.Model.Selection.Selected_Index (Runtime.Model) then
                  return Cell.Height > 0;
               end if;
            end loop;
            return False;
         end;
      end Selected_Shown;

      --  Press (and later release) the left button over the item with
      --  Visible_Index, through the window's own mouse step.
      procedure Press_Item (Visible_Index : Positive) is separate;

      --  Release the left button where it went down, without a drag.
      procedure Release_Left is
      begin
         Runtime.Handle.Pending_Mouse.Append
           (Guikit.Input.Mouse_Buttons.Button_Event'
              (Button    => Guikit.Input.Mouse_Buttons.Left_Mouse_Button,
               Pressed   => False,
               X         => Runtime.Handle.Drag_Start_X,
               Y         => Runtime.Handle.Drag_Start_Y,
               Modifiers => Guikit.Input.No_Modifiers,
               Dragged   => False,
               --  Long past its debounce window, so the next drain takes it.
               At_Time   => Ada.Real_Time.Time_First));
      end Release_Left;

      --  The list: the selection follows the keyboard into view, and a press on
      --  part of the selection keeps all of it until a release without a drag.
      procedure Check_List_Keys is separate;

      --  A double click opens a folder; a third click straight after, on
      --  whatever sits at that row of the folder now shown, opens nothing.
      --  Folders only, so even a regression opens no program.
      procedure Check_Click_Opens_Once is separate;
   begin
      Failed_Step := 0;
      if Runtime.Handle = null then
         Failed_Step := 1;
         return;
      end if;

      Press (Guikit.Input.Key_Comma, Ctrl);
      Expect (Open);

      Check_Field_Keys;
      Check_Toggle;
      Check_Sections_And_Close;
      Check_List_Keys;
      Check_Click_Opens_Once;

      --  Reopen and leave it on the second tab, so the final frame shows the
      --  panel the keys drove rather than the startup view.
      Press (Guikit.Input.Key_Comma, Ctrl);
      Expect (Open);
      Press (Guikit.Input.Key_Tab, Ctrl);
      Expect (Files.Model.Settings_Pane.Active_Section (Runtime.Model) = 2);
   end Drive_Settings_Keys;
