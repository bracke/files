separate (Files.Application.Windows)
procedure Save_Held_Settings (Runtime : in out Runtime_Window; Force : Boolean) is
   --  Long enough for a system's slowest key repeat to arrive again.
   Held_Settings_Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1_000);
begin
   if not Files.Model.Settings_Pane.Save_Is_Deferred (Runtime.Model)
     or else (not Force
              and then Runtime.Handle /= null
              and then Runtime.Handle.Key_Held
              and then Ada.Real_Time.Clock < Runtime.Settings_Repeat_At + Held_Settings_Timeout)
   then
      return;
   end if;
   if Files.Model.Settings_Pane.Take_Deferred_Save (Runtime.Model) then
      --  Every accepted step is in force already (the folder read again
      --  where one needed it): what is written is the settings in force,
      --  never the pane's draft again.
      Files.Controller.Persist_Held_Settings
        (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path));
   end if;
end Save_Held_Settings;
