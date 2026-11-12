package body Files.Mouse_Buttons is

   use type Ada.Real_Time.Time;

   procedure Queue_Event
     (Queue           : in out Button_Event_Vectors.Vector;
      Last_Left_Press : in out Ada.Real_Time.Time;
      Event           : Button_Event;
      Now             : Ada.Real_Time.Time;
      Bounced         : out Boolean)
   is
   begin
      Bounced := False;
      if Event.Button = Left_Mouse_Button and then Event.Pressed then
         if Now < Last_Left_Press + Left_Press_Debounce then
            Bounced := True;
            --  The bounce's release came first and was queued: withdraw it.
            for Index in reverse Queue.First_Index .. Queue.Last_Index loop
               if Queue (Index).Button = Left_Mouse_Button then
                  if not Queue (Index).Pressed then
                     Queue.Delete (Index);
                  end if;
                  exit;
               end if;
            end loop;
            return;
         end if;
         Last_Left_Press := Now;
      end if;
      if Natural (Queue.Length) < Max_Pending_Events then
         Queue.Append (Event);
      end if;
   end Queue_Event;

end Files.Mouse_Buttons;
