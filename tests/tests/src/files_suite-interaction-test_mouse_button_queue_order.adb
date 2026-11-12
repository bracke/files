separate (Files_Suite.Interaction)
   --  Mouse button changes wait in arrival order, each with where it happened
   --  and the modifiers held then; a bounce's press is dropped together with
   --  its release, so a held drag is not ended by it.
   procedure Test_Mouse_Button_Queue_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Mouse_Buttons;
      use type Ada.Real_Time.Time;
      use type Glfw.Input.Mouse.Coordinate;
      Queue   : Button_Event_Vectors.Vector;
      Last    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Start   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Bounced : Boolean;
      Ctrl    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;

      function Millis (Count : Natural) return Ada.Real_Time.Time is
        (Start + Ada.Real_Time.Milliseconds (Count));

      function Event
        (Button : Button_Kind; Pressed : Boolean; X : Glfw.Input.Mouse.Coordinate; At_Millis : Natural;
         Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers) return Button_Event is
        (Button => Button, Pressed => Pressed, X => X, Y => X + 1.0, Modifiers => Modifiers, Dragged => False,
         At_Time => Millis (At_Millis));
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, True, 10.0, 0, Ctrl), Bounced);
      Assert (not Bounced, "a first press is no bounce");
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, False, 10.0, 100), Bounced);
      Queue_Event (Queue, Last, Event (Right_Mouse_Button, True, 20.0, 200), Bounced);
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, True, 30.0, 300), Bounced);
      Assert (not Bounced, "a press well after the last one is no bounce");

      Assert (Natural (Queue.Length) = 4, "every change waits");
      Assert (Queue (1).Button = Left_Mouse_Button and then Queue (1).Pressed and then Queue (1).X = 10.0,
              "the first press comes first, where it went down");
      Assert (Queue (1).Modifiers (Guikit.Input.Control_Key), "a press keeps the modifiers held when it happened");
      Assert (Queue (2).Button = Left_Mouse_Button and then not Queue (2).Pressed,
              "its release follows it");
      Assert (Queue (3).Button = Right_Mouse_Button and then Queue (3).X = 20.0
              and then not Queue (3).Modifiers (Guikit.Input.Control_Key),
              "a right click keeps its place between the left clicks");
      Assert (Queue (4).X = 30.0 and then Queue (4).Y = 31.0, "the second left press keeps its own position");

      --  A switch bounce: release and press again within the debounce window.
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, False, 30.0, 305), Bounced);
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, True, 30.0, 310), Bounced);
      Assert (Bounced, "a press within the debounce window is a bounce");
      Assert (Natural (Queue.Length) = 4, "the bounce's press and its release are both dropped");
      Assert (Queue.Last_Element.Pressed, "the held press stays the last change");

      --  A bounce with no release waiting withdraws nothing else.
      Queue_Event (Queue, Last, Event (Left_Mouse_Button, True, 30.0, 320), Bounced);
      Assert (Bounced and then Natural (Queue.Length) = 4, "a bounce never withdraws a press");

      Queue.Clear;
      for Index in 1 .. Max_Pending_Events + 4 loop
         Queue_Event (Queue, Last, Event (Right_Mouse_Button, True, 1.0, 1_000), Bounced);
      end loop;
      Assert (Natural (Queue.Length) = Max_Pending_Events, "the queue is bounded");
   end Test_Mouse_Button_Queue_Order;
