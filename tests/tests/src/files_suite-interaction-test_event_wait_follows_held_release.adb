with Guikit.Input.Mouse_Buttons;
separate (Files_Suite.Interaction)
   --  The event loop's wait (Files.Event_Wait.Window_Wait, which
   --  Files.Application.Windows.Event_Loop_Wait folds over every window): a
   --  left release held back for its debounce window cuts the wait to the
   --  time left in that window, one already due cuts it to the prompt wait,
   --  and an empty queue -- Time_Last, at either end of the clock -- leaves
   --  the normal limit.
   procedure Test_Event_Wait_Follows_Held_Release (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Guikit.Input.Mouse_Buttons;
      use type Ada.Real_Time.Time;
      use type Ada.Real_Time.Time_Span;

      Limit   : constant Duration := 0.016;
      Prompt  : constant Duration := 0.001;
      Start   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Half    : constant Ada.Real_Time.Time_Span := Left_Press_Debounce / 2;
      Queue   : Button_Event_Vectors.Vector;
      Last    : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Bounced : Boolean;

      function Wait
        (Now    : Ada.Real_Time.Time;
         Ready  : Ada.Real_Time.Time;
         Within : Duration;
         Paste  : Boolean := False;
         Short  : Duration := Prompt)
         return Duration
      is (Files.Event_Wait.Window_Wait
            (Now     => Now,
             Pending => (Background_Paste => Paste, Mouse_Ready => Ready),
             Limit   => Within,
             Prompt  => Short));

      function Near (Left, Right : Duration) return Boolean is (abs (Left - Right) < 0.000_001);
   begin
      --  A left release queued at Start is held until its debounce window closes.
      Queue_Event
        (Queue, Last,
         (Button => Left_Mouse_Button, Pressed => False, X => 5.0, Y => 5.0,
          Modifiers => Guikit.Input.No_Modifiers, Dragged => False, At_Time => Start),
         Bounced);
      Assert (not Bounced, "a lone release is no bounce");
      Assert (Ready_At (Queue) = Start + Left_Press_Debounce, "the queued release is held for its debounce window");

      Assert (Near (Wait (Start + Half, Ready_At (Queue), 10.0),
                    Ada.Real_Time.To_Duration (Left_Press_Debounce - Half)),
              "a held release cuts the wait to the time left in its debounce window");
      Assert (Wait (Start + Half, Ready_At (Queue), Limit) <= Limit,
              "a held release never lengthens the wait past the limit");
      Assert (Wait (Start, Ready_At (Queue), 10.0) <= Ada.Real_Time.To_Duration (Left_Press_Debounce),
              "the wait is at most the release's remaining time");

      --  Once due, the release is handled on the next pass.
      Assert (Wait (Start + Left_Press_Debounce, Ready_At (Queue), Limit) = Prompt,
              "a release due now cuts the wait to the prompt wait");
      Assert (Wait (Start + Left_Press_Debounce + Half, Ready_At (Queue), Limit, Short => 0.0) = 0.0,
              "a release past due gives no wait when the prompt wait is zero");

      --  Nothing queued: the normal limit, wherever the clock stands.
      Queue.Clear;
      Assert (Ready_At (Queue) = Ada.Real_Time.Time_Last, "an empty queue is never due");
      Assert (Wait (Start, Ready_At (Queue), Limit) = Limit, "with no release pending the wait is the normal limit");
      Assert (Wait (Ada.Real_Time.Time_First, Ada.Real_Time.Time_Last, Limit) = Limit,
              "Time_Last seen from the clock's start clamps to the limit without overflowing");
      Assert (Wait (Ada.Real_Time.Time_Last, Ada.Real_Time.Time_Last, Limit) = Prompt,
              "at the clock's end Time_Last counts as due");

      --  A background paste cuts the wait to the prompt one by itself.
      Assert (Wait (Start, Ada.Real_Time.Time_Last, Limit, Paste => True) = Prompt,
              "a running background paste cuts the wait to the prompt wait");

      --  Folded over windows (Event_Loop_Wait): the shortest wins.
      Assert
        (Near
           (Wait (Start + Half, Start + Left_Press_Debounce,
                  Wait (Start + Half, Ada.Real_Time.Time_Last, 10.0)),
            Ada.Real_Time.To_Duration (Left_Press_Debounce - Half)),
         "one window's held release shortens the wait another window allowed");
   end Test_Event_Wait_Follows_Held_Release;
