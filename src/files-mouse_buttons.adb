package body Files.Mouse_Buttons is

   use type Ada.Real_Time.Time;

   procedure Queue_Event
     (Queue           : in out Button_Event_Vectors.Vector;
      Last_Left_Press : in out Ada.Real_Time.Time;
      Event           : Button_Event;
      Bounced         : out Boolean)
   is
   begin
      Bounced := False;
      if Event.Button = Left_Mouse_Button and then Event.Pressed then
         if Event.At_Time < Last_Left_Press + Left_Press_Debounce then
            Bounced := True;
            --  The bounce's release came first and is still held back in
            --  Queue (Next_Ready keeps it there for the debounce window):
            --  withdraw it.
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
         Last_Left_Press := Event.At_Time;
      end if;
      if Natural (Queue.Length) < Max_Pending_Events then
         Queue.Append (Event);
      end if;
   end Queue_Event;

   function Ready_At (Queue : Button_Event_Vectors.Vector) return Ada.Real_Time.Time is
   begin
      if Queue.Is_Empty then
         return Ada.Real_Time.Time_Last;
      end if;
      declare
         First : constant Button_Event := Queue.First_Element;
      begin
         if First.Button = Left_Mouse_Button and then not First.Pressed then
            return First.At_Time + Left_Press_Debounce;
         end if;
         return First.At_Time;
      end;
   end Ready_At;

   procedure Next_Ready
     (Queue : in out Button_Event_Vectors.Vector;
      Now   : Ada.Real_Time.Time;
      Event : out Button_Event;
      Taken : out Boolean) is
   begin
      Event := (others => <>);
      Taken := not Queue.Is_Empty and then Ready_At (Queue) <= Now;
      if Taken then
         Event := Queue.First_Element;
         Queue.Delete_First;
      end if;
   end Next_Ready;

end Files.Mouse_Buttons;
