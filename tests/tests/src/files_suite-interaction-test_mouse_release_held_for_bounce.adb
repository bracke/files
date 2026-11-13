with Guikit.Input.Mouse_Buttons;
separate (Files_Suite.Interaction)
   --  A left release is held back for its debounce window: a drain before the
   --  bounce press arrives leaves it queued, so the bounce still withdraws it
   --  and the held drag is not ended. A release older than the window drains.
   procedure Test_Mouse_Release_Held_For_Bounce (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Input.Mouse_Buttons;
      use type Ada.Real_Time.Time;
      Queue   : Button_Event_Vectors.Vector;
      Last    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Start   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Bounced : Boolean;
      Taken   : Boolean;
      Drained : Button_Event;

      function Millis (Count : Natural) return Ada.Real_Time.Time is
        (Start + Ada.Real_Time.Milliseconds (Count));

      function Left (Pressed : Boolean; At_Millis : Natural) return Button_Event is
        (Button => Left_Mouse_Button, Pressed => Pressed, X => 5.0, Y => 5.0,
         Modifiers => Guikit.Input.No_Modifiers, Dragged => False, At_Time => Millis (At_Millis));
   begin
      Queue_Event (Queue, Last, Left (True, 0), Bounced);
      Next_Ready (Queue, Millis (1), Drained, Taken);
      Assert (Taken and then Drained.Pressed, "a press drains at once");

      --  The bounce's release arrives, the window drains before the bounce's
      --  press does: the release must stay queued.
      Queue_Event (Queue, Last, Left (False, 5), Bounced);
      Next_Ready (Queue, Millis (6), Drained, Taken);
      Assert (not Taken, "a release inside its debounce window is held back");
      Assert (Natural (Queue.Length) = 1, "the held-back release still waits");
      Assert (Ready_At (Queue) = Millis (5) + Left_Press_Debounce, "it is ready when its window closes");

      Queue_Event (Queue, Last, Left (True, 10), Bounced);
      Assert (Bounced, "the second press within the window is a bounce");
      Assert (Queue.Is_Empty, "the bounce withdraws the held-back release with its press: the drag is still held");
      Next_Ready (Queue, Millis (200), Drained, Taken);
      Assert (not Taken, "nothing of the bounce is ever drained");

      --  The real release, drained only after its window has passed.
      Queue_Event (Queue, Last, Left (False, 500), Bounced);
      Queue_Event
        (Queue, Last,
         (Button => Right_Mouse_Button, Pressed => True, X => 9.0, Y => 9.0,
          Modifiers => Guikit.Input.No_Modifiers, Dragged => False, At_Time => Millis (510)),
         Bounced);
      Next_Ready (Queue, Millis (520), Drained, Taken);
      Assert (not Taken and then Natural (Queue.Length) = 2,
              "a change after a held-back release waits behind it, in order");
      Next_Ready (Queue, Millis (500) + Left_Press_Debounce, Drained, Taken);
      Assert (Taken and then Drained.Button = Left_Mouse_Button and then not Drained.Pressed,
              "a release older than the window drains normally");
      Next_Ready (Queue, Millis (600), Drained, Taken);
      Assert (Taken and then Drained.Button = Right_Mouse_Button, "the change after it follows");
      Assert (Queue.Is_Empty and then Ready_At (Queue) = Ada.Real_Time.Time_Last,
              "an empty queue never wakes the loop");
   end Test_Mouse_Release_Held_For_Bounce;
