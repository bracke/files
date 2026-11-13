with Files.Event_Wait;
separate (Files.Application.Windows)
   function Event_Loop_Wait (Runtime_Windows : Runtime_Window_Vectors.Vector) return Duration is
      Pending : Files.Event_Wait.Pending_List (1 .. Natural (Runtime_Windows.Length));
      Open    : Natural := 0;
   begin
      --  Gather what each open window has pending; the fold (tested in the
      --  suite) decides the wait.
      for Runtime of Runtime_Windows loop
         if Runtime.Handle /= null then
            Open := Open + 1;
            Pending (Open) :=
              (Background_Paste =>
                 Files.Model.Pasting.Execution_Is_Active (Runtime.Model)
                 and then Files.Model.Background_Transfers (Runtime.Model),
               Mouse_Ready      => Guikit.Input.Mouse_Buttons.Ready_At (Runtime.Handle.Pending_Mouse));
         end if;
      end loop;
      return
        Files.Event_Wait.Fold
          (Now     => Ada.Real_Time.Clock,
           Windows => Pending (1 .. Open),
           Limit   => Event_Wait_Timeout,
           Prompt  => Paste_Wait_Timeout);
   end Event_Loop_Wait;
