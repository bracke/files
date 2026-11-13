separate (Files_Suite.Interaction)
   --  The event loop's wait over every open window (Files.Event_Wait.Fold,
   --  which Files.Application.Windows.Event_Loop_Wait asks with what each
   --  window has pending): with no window, or none with anything pending,
   --  the normal wait; otherwise the shortest wait any window allows --
   --  wherever that window stands in the list -- and never past the normal
   --  wait. A held release counts for the time left in its debounce window,
   --  a due one and a running background paste for the prompt wait.
   procedure Test_Event_Wait_Folds_Over_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      subtype Pending is Files.Event_Wait.Window_Pending;
      subtype List is Files.Event_Wait.Pending_List;

      Limit  : constant Duration := 0.016;
      Prompt : constant Duration := 0.001;
      Now    : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Idle   : constant Pending := (Background_Paste => False, Mouse_Ready => Ada.Real_Time.Time_Last);
      Held_5 : constant Pending := (Background_Paste => False, Mouse_Ready => Now + Ada.Real_Time.Milliseconds (5));
      Held_9 : constant Pending := (Background_Paste => False, Mouse_Ready => Now + Ada.Real_Time.Milliseconds (9));
      Due    : constant Pending := (Background_Paste => False, Mouse_Ready => Now);
      Paste  : constant Pending := (Background_Paste => True, Mouse_Ready => Ada.Real_Time.Time_Last);
      None   : constant List (1 .. 0) := [others => Idle];

      function Fold (Windows : List; Within : Duration := Limit) return Duration is
        (Files.Event_Wait.Fold (Now => Now, Windows => Windows, Limit => Within, Prompt => Prompt));

      function Near (Left, Right : Duration) return Boolean is (abs (Left - Right) < 0.000_001);
   begin
      Assert (Fold (None) = Limit, "with no window open the wait is the normal one");
      Assert (Fold ([Idle, Idle, Idle]) = Limit, "windows with nothing pending leave the normal wait");
      Assert (Fold (None, Within => -1.0) = 0.0, "the wait is never negative");

      --  The shortest wait wins, whichever window allows it.
      Assert (Near (Fold ([Idle, Held_9, Held_5]), 0.005), "the window last in the list allows the shortest wait");
      Assert (Near (Fold ([Held_5, Held_9, Idle]), 0.005),
              "the window first in the list allows the shortest wait, and a later window does not lengthen it");
      Assert (Near (Fold ([Held_9, Held_5, Held_9]), 0.005), "a window in the middle allows the shortest wait");

      --  No window lengthens the normal wait.
      Assert (Fold ([Held_9, Idle], Within => 0.003) = 0.003, "a held release never lengthens the normal wait");

      --  A mouse change already due, or a running background paste, in any
      --  window: the prompt wait.
      Assert (Fold ([Held_9, Due, Idle]) = Prompt, "a due mouse change in one window gives the prompt wait");
      Assert (Fold ([Idle, Paste, Held_5]) = Prompt, "a background paste in one window gives the prompt wait");
      Assert (Fold ([Held_5, Idle, Paste]) = Prompt, "a background paste in the last window gives the prompt wait");
   end Test_Event_Wait_Folds_Over_Windows;
