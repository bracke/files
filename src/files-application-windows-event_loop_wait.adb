with Files.Event_Wait;
separate (Files.Application.Windows)
   function Event_Loop_Wait (Runtime_Windows : Runtime_Window_Vectors.Vector) return Duration is
      Now  : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Wait : Duration := Event_Wait_Timeout;
   begin
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null then
            Wait :=
              Files.Event_Wait.Window_Wait
                (Now     => Now,
                 Pending =>
                   (Background_Paste =>
                      Files.Model.Paste_Execution_Is_Active (Runtime.Model)
                      and then Files.Model.Background_Transfers (Runtime.Model),
                    Mouse_Ready      => Files.Mouse_Buttons.Ready_At (Runtime.Handle.Pending_Mouse)),
                 Limit   => Wait,
                 Prompt  => Paste_Wait_Timeout);
         end if;
      end loop;
      return Wait;
   end Event_Loop_Wait;
