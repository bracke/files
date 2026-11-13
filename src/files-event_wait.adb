with Files.Timing;

package body Files.Event_Wait is

   function Window_Wait
     (Now     : Ada.Real_Time.Time;
      Pending : Window_Pending;
      Limit   : Duration;
      Prompt  : Duration)
      return Duration
   is
      use type Ada.Real_Time.Time;
      Wait : Duration := Duration'Max (Limit, 0.0);
   begin
      if Pending.Background_Paste then
         Wait := Duration'Min (Wait, Duration'Max (Prompt, 0.0));
      end if;
      --  A release held back for its debounce window is handled on the
      --  first pass after the window closes, not a whole wait later.
      if Pending.Mouse_Ready <= Now then
         Wait := Duration'Min (Wait, Duration'Max (Prompt, 0.0));
      else
         Wait := Files.Timing.Until_Due (Now, Pending.Mouse_Ready, Wait);
      end if;
      return Wait;
   end Window_Wait;

   function Fold
     (Now     : Ada.Real_Time.Time;
      Windows : Pending_List;
      Limit   : Duration;
      Prompt  : Duration)
      return Duration
   is
      Wait : Duration := Duration'Max (Limit, 0.0);
   begin
      for Pending of Windows loop
         Wait := Window_Wait (Now => Now, Pending => Pending, Limit => Wait, Prompt => Prompt);
      end loop;
      return Wait;
   end Fold;

end Files.Event_Wait;
