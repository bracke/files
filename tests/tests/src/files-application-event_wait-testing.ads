--  What the suite reaches of Files.Application.Event_Wait that is not part of its interface.
package Files.Application.Event_Wait.Testing is

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

end Files.Application.Event_Wait.Testing;
