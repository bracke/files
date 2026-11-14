with Files.Model.Settings_Pane;
separate (Files.Application.Windows)
   procedure Perform_Accessibility_Request
     (Runtime : in out Runtime_Window;
      Item    : A11ykit.Provider.Request)
   is
      use type A11ykit.Provider.Request_Kind;
      Window_W, Window_H, Frame_W, Frame_H : Glfw.Size := 0;
   begin
      if Runtime.Handle = null then
         return;
      end if;
      Glfw.Windows.Get_Size (As_Window (Runtime.Handle), Window_W, Window_H);
      Glfw.Windows.Get_Framebuffer_Size (As_Window (Runtime.Handle), Frame_W, Frame_H);
      if Frame_W = 0 or else Frame_H = 0 then
         return;
      end if;
      declare
         --  Node rectangles are framebuffer pixels; the click path takes
         --  window coordinates.
         Centre_X : constant Float := Float (Item.Bounds.X) + Float (Item.Bounds.Width) / 2.0;
         Centre_Y : constant Float := Float (Item.Bounds.Y) + Float (Item.Bounds.Height) / 2.0;
         Action   : Files.Events.Input_Action :=
           Current_Click_Action
             (Runtime, Window_W, Window_H, Frame_W, Frame_H,
              Glfw.Input.Mouse.Coordinate (Centre_X * Float (Window_W) / Float (Frame_W)),
              Glfw.Input.Mouse.Coordinate (Centre_Y * Float (Window_H) / Float (Frame_H)),
              Guikit.Input.No_Modifiers);
         --  Activate opens an item (a double-click) or sorts by a header;
         --  Select and Focus are the single click.
         Activate : constant Boolean := Item.Kind = A11ykit.Provider.Activate_Request;
      begin
         Action := Files.Window_Policy.Accessibility_Action (Action, Activate);
         Files.Diagnostics.Trace
           ("Files.Application.Windows",
            --  A developer trace: field=value pairs, no prose.
            "x=" & Natural'Image (Item.Bounds.X) & ',' & "y=" & Natural'Image (Item.Bounds.Y)
            & ',' & "action=" & Files.Events.Input_Action_Kind'Image (Action.Kind)
            & ',' & "item="
            & (if Action.Kind = Files.Events.Item_Click_Input_Action then Action.Item_Index'Image else " 0"));
         Dispatch_Click_Action (Runtime, Action, Guikit.Input.No_Modifiers);
         Files.Diagnostics.Trace
           ("Files.Application.Windows",
            "selected=" & Natural'Image (Files.Model.Selection.Selected_Count (Runtime.Model)));

         --  Space on the focused field changes it, saving included.
         if Files.Window_Policy.Activation_Presses_Space
           (Activate, Files.Model.Focus (Runtime.Model), Files.Model.Settings_Pane.Focused_Kind (Runtime.Model))
         then
            declare
               Consumed : Boolean;
            begin
               Fire_Key (Runtime, Guikit.Input.Key_Space, Guikit.Input.No_Modifiers, Consumed);
            end;
         end if;
      end;
   end Perform_Accessibility_Request;
