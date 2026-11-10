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
      begin
         --  Activate opens an item, as a double-click does; Select and Focus
         --  are the single click, which selects it and opens nothing.
         if Item.Kind = A11ykit.Provider.Activate_Request
           and then Action.Kind = Files.Events.Item_Click_Input_Action
         then
            Action.Activate := True;
         end if;
         --  A header cell's press only arms a drag that sorts on release
         --  under the real pointer: activating it sorts by its column.
         if Action.Kind = Files.Events.Column_Reorder_Begin_Input_Action then
            Action :=
              (if Action.Sort_Command /= Files.Commands.No_Command
               then (Kind => Files.Events.Command_Input_Action, Command => Action.Sort_Command)
               else (Kind => Files.Events.No_Input_Action));
         end if;
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
            "selected=" & Natural'Image (Files.Model.Selected_Count (Runtime.Model)));

         --  A click on a settings row's middle only focuses it; activating a
         --  toggle or choice should change it, as Space on the focused field
         --  does (saving included).
         if Item.Kind = A11ykit.Provider.Activate_Request
           and then Files.Model.Focus (Runtime.Model) = Files.Types.Focus_Settings_Input
           and then Files.Model.Settings_Focused_Kind (Runtime.Model) in
             Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice
         then
            declare
               Consumed : Boolean;
            begin
               Fire_Key (Runtime, Tracked_Space, Guikit.Input.No_Modifiers, Consumed);
            end;
         end if;
      end;
   end Perform_Accessibility_Request;
