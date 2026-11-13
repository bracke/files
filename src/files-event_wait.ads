with Ada.Real_Time;

--  How long the event loop may sleep waiting for input, decided from what
--  the windows have pending rather than from the windows themselves, so the
--  suite can check it without one. Files.Application.Windows.Event_Loop_Wait
--  only gathers each open window's pending work and asks Fold.
package Files.Event_Wait is

   --  What one window has pending that may cut the wait short.
   type Window_Pending is record
      --  A paste carried out through a helper process is under way: its
      --  progress is polled, not posted as an event.
      Background_Paste : Boolean := False;
      --  When the oldest queued mouse change may be handled
      --  (Guikit.Input.Mouse_Buttons.Ready_At): the end of the debounce window of
      --  a held-back left release, Time_Last for an empty queue.
      Mouse_Ready : Ada.Real_Time.Time := Ada.Real_Time.Time_Last;
   end record;

   --  What every open window has pending, one entry a window.
   type Pending_List is array (Positive range <>) of Window_Pending;

   --  The wait one window allows.
   --
   --  @param Now The current time.
   --  @param Pending What the window has pending.
   --  @param Limit The wait allowed so far; the longest answer.
   --  @param Prompt The short wait for work that is due now: a running
   --    background paste, or a mouse change whose time has come.
   --  @return Limit, cut to Prompt while a background paste runs or when the
   --    mouse change is already due, and to the time left until it becomes
   --    due otherwise. Never more than Limit, never negative, never raises,
   --    wherever in the clock's range Now and Mouse_Ready lie.
   function Window_Wait
     (Now     : Ada.Real_Time.Time;
      Pending : Window_Pending;
      Limit   : Duration;
      Prompt  : Duration)
      return Duration;

   --  The wait all windows allow: Window_Wait folded over Windows, each
   --  window's answer the next one's limit, so the shortest wins.
   --
   --  @param Now The current time.
   --  @param Windows What each open window has pending.
   --  @param Limit The loop's normal wait; the answer with no window, or
   --    none with anything pending.
   --  @param Prompt The short wait for work that is due now.
   --  @return The shortest wait any window allows, at most Limit, never
   --    negative.
   function Fold
     (Now     : Ada.Real_Time.Time;
      Windows : Pending_List;
      Limit   : Duration;
      Prompt  : Duration)
      return Duration;

end Files.Event_Wait;
