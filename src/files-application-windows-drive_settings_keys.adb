with Guikit.Settings_Panel;
with Hostkit.Fs;

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

         --  A screen reader's "activate" on the focused toggle flips it too,
         --  through the path its requests take (a click on the node's
         --  centre, which only focuses a settings row, then its change).
         declare
            Shown  : constant Guikit.Draw.Accessibility_Node_Vectors.Vector := Runtime.Shown_Accessibility;
            Was    : constant String := Files.Model.Settings_Focused_Value (Runtime.Model);
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
            Expect (Asked and then Files.Model.Settings_Focused_Value (Runtime.Model) /= Was);
         end;
      end;

      Press (Tracked_Tab, Ctrl);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 2);
      Press (Tracked_Tab, Ctrl_Shift);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 1);

      Press (Tracked_Escape);
      Expect (not Files.Model.Settings_Pane_Is_Open (Runtime.Model)
              and then Files.Model.Focus (Runtime.Model) = Files.Types.Focus_None);

      --  The list: the selection follows the keyboard into view, and a press on
      --  part of the selection keeps all of it until a release without a drag.
      declare
         function Selected_Shown return Boolean is
            Frame_W, Frame_H : Glfw.Size := 0;
            Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         begin
            Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
            declare
               Snapshot : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
               Layout   : constant Files.Rendering.Layout_Metrics :=
                 Files.Rendering.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
            begin
               for Cell of Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height) loop
                  if Cell.Visible_Index = Files.Model.Selected_Index (Runtime.Model) then
                     return Cell.Height > 0;
                  end if;
               end loop;
               return False;
            end;
         end Selected_Shown;

         --  Press (and later release) the left button over the item with
         --  Visible_Index, through the window's own mouse step.
         procedure Press_Item (Visible_Index : Positive) is
            Window_W, Window_H, Frame_W, Frame_H : Glfw.Size := 0;
            Line_Height : constant Positive := Cell_Height_For (Runtime.Font_Pixel_Size);
         begin
            Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
            Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
            declare
               Snapshot : constant Files.Rendering.View_Snapshot :=
                 Files.Rendering.Build_Snapshot (Runtime.Model, Runtime.Settings);
               Layout   : constant Files.Rendering.Layout_Metrics :=
                 Files.Rendering.Calculate_Layout (Snapshot, Natural (Frame_W), Natural (Frame_H), Line_Height);
            begin
               for Cell of Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line_Height) loop
                  if Cell.Visible_Index = Visible_Index and then Cell.Height > 0 and then Frame_W > 0 then
                     Runtime.Handle.Drag_Start_X :=
                       Glfw.Input.Mouse.Coordinate
                         (Float (Cell.X + Cell.Width / 2) * Float (Window_W) / Float (Frame_W));
                     Runtime.Handle.Drag_Start_Y :=
                       Glfw.Input.Mouse.Coordinate
                         (Float (Cell.Y + Cell.Height / 2) * Float (Window_H) / Float (Frame_H));
                     Runtime.Handle.Pending_Left_Clicks := 1;
                     Runtime.Handle.Drag_Moved := False;
                     Handle_Mouse (Runtime);
                     exit;
                  end if;
               end loop;
            end;
         end Press_Item;
      begin
         Files.Model.Replace_Items (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
         Files.Model.Set_View_Mode (Runtime.Model, Files.Types.Details);
         Files.Model.Select_Visible (Runtime.Model, 1);
         Render_Window (Runtime);
         Press (Tracked_End);
         Expect (Files.Model.Main_View_Scroll_Lines (Runtime.Model) > 0 and then Selected_Shown);
         Press (Tracked_Home);
         Expect (Files.Model.Main_View_Scroll_Lines (Runtime.Model) = 0 and then Selected_Shown);
         Press (Tracked_Page_Down);
         Expect (Files.Model.Selected_Index (Runtime.Model) > 2 and then Selected_Shown);

         Press (Tracked_Home);
         Files.Model.Select_All_Visible (Runtime.Model);
         Press_Item (2);
         Expect (Files.Model.Selected_Count (Runtime.Model) = Files.Model.Visible_Count (Runtime.Model));
         Runtime.Handle.Pending_Left_Releases := 1;
         Handle_Mouse (Runtime);
         Expect (Files.Model.Selected_Count (Runtime.Model) = 1
                 and then Files.Model.Selected_Index (Runtime.Model) = 2);
         Runtime.Last_Click_Item := 0;
         Runtime.Last_Click_Path := Null_Unbounded_String;

         --  A double click opens a folder; a third click straight after, on
         --  whatever sits at that row of the folder now shown, opens nothing.
         --  Folders only, so even a regression opens no program.
         declare
            Base  : constant String := Hostkit.Fs.Create_Temporary_Directory ("files-live-click");
            Inner : constant String := Hostkit.Fs.Join (Base, "inner");

            procedure Show (Path : String) is
               Load : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (Path, Runtime.Settings);
            begin
               Files.Model.Navigate_To (Runtime.Model, Path, Load.Items);
               Render_Window (Runtime);
            end Show;

            procedure Click (Visible_Index : Positive) is
            begin
               Press_Item (Visible_Index);
               Runtime.Handle.Pending_Left_Releases := 1;
               Handle_Mouse (Runtime);
               Render_Window (Runtime);
            end Click;
         begin
            if Base /= "" then
               Ada.Directories.Create_Path (Hostkit.Fs.Join (Inner, "deeper"));
               Show (Base);
               Click (1);
               --  A frame between the clicks can take longer than a double
               --  click allows on a slow host: the step is about matching the
               --  clicks, not the host's speed.
               Runtime.Last_Click_Time := Ada.Real_Time.Clock;
               Click (1);
               Expect (Files.Model.Current_Path (Runtime.Model) = Ada.Directories.Full_Name (Inner));
               Runtime.Last_Click_Time := Ada.Real_Time.Clock;
               Click (1);
               Expect (Files.Model.Current_Path (Runtime.Model) = Ada.Directories.Full_Name (Inner));
               Runtime.Last_Click_Item := 0;
               Runtime.Last_Click_Path := Null_Unbounded_String;
               Files.Model.Replace_Items (Runtime.Model, Scenario_Overflow_Items (Runtime.Model));
               Ada.Directories.Delete_Tree (Base);
            end if;
         end;
      end;

      --  Reopen and leave it on the second tab, so the final frame shows the
      --  panel the keys drove rather than the startup view.
      Press (Tracked_Comma, Ctrl);
      Expect (Open);
      Press (Tracked_Tab, Ctrl);
      Expect (Files.Model.Settings_Active_Section (Runtime.Model) = 2);
   end Drive_Settings_Keys;
