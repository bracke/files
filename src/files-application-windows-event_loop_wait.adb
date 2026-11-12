with Files.Timing;
separate (Files.Application.Windows)
   function Event_Loop_Wait (Runtime_Windows : Runtime_Window_Vectors.Vector) return Duration is
      Now  : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Wait : Duration := Event_Wait_Timeout;
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null then
            if Files.Model.Paste_Execution_Is_Active (Runtime.Model)
              and then Files.Model.Background_Transfers (Runtime.Model)
            then
               Wait := Duration'Min (Wait, Paste_Wait_Timeout);
            end if;
            --  A release held back for its debounce window is handled on the
            --  first pass after the window closes, not a whole wait later.
            declare
               Ready : constant Ada.Real_Time.Time := Files.Mouse_Buttons.Ready_At (Runtime.Handle.Pending_Mouse);
            begin
               if Ready <= Now then
                  Wait := Duration'Min (Wait, Paste_Wait_Timeout);
               else
                  Wait := Files.Timing.Until_Due (Now, Ready, Wait);
               end if;
            end;
         end if;
      end loop;
      return Wait;
   end Event_Loop_Wait;
