separate (Files.Application.Windows)
   overriding procedure Mouse_Button_Changed
     (Object : not null access Desktop_Window;
      Button : Glfw.Input.Mouse.Button;
      State  : Glfw.Input.Button_State;
      Mods   : Glfw.Input.Keys.Modifiers)
   is
      use type Guikit.Input.Mouse_Buttons.Button_Kind;
      Event   : Guikit.Input.Mouse_Buttons.Button_Event :=
        (Button    => Guikit.Input.Mouse_Buttons.Left_Mouse_Button,
         Pressed   => State = Glfw.Input.Pressed,
         X         => Object.Last_Mouse_X,
         Y         => Object.Last_Mouse_Y,
         Modifiers => Glfw.Input.Keys.Codes.To_Modifiers (Mods),
         Dragged   => False,
         At_Time   => Ada.Real_Time.Clock);
      Bounced : Boolean;
   begin
      if Button = Glfw.Input.Mouse.Right_Button then
         --  A right-click acts on the press, where it went down.
         if State /= Glfw.Input.Pressed then
            return;
         end if;
         Event.Button := Guikit.Input.Mouse_Buttons.Right_Mouse_Button;
      elsif Button /= Glfw.Input.Mouse.Left_Button then
         return;
      elsif not Event.Pressed then
         Event.Dragged := Object.Drag_Moved;
      end if;

      Guikit.Input.Mouse_Buttons.Queue_Event
        (Object.Pending_Mouse, Object.Last_Left_Press_Time, Event, Bounced);
      if Event.Button /= Guikit.Input.Mouse_Buttons.Left_Mouse_Button then
         return;
      elsif not Event.Pressed then
         Object.Left_Mouse_Down := False;
      elsif Bounced then
         --  The button is physically down again after the bounce's release.
         Object.Left_Mouse_Down := True;
      else
         Object.Left_Mouse_Down := True;
         Object.Drag_Start_X := Event.X;
         Object.Drag_Start_Y := Event.Y;
         Object.Drag_Moved := False;
      end if;
   exception
      when Swallowed : others =>
         --  GLFW calls this from C: an exception must not unwind into it.
         --  The event is lost, the window is not.
         Files.Diagnostics.Note_Event_Loop (Swallowed);
   end Mouse_Button_Changed;
