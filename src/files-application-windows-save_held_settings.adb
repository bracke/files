with Files.Commands;
separate (Files.Application.Windows)
procedure Save_Held_Settings (Runtime : in out Runtime_Window; Force : Boolean) is
   --  Long enough for a system's slowest key repeat to arrive again.
   Held_Settings_Timeout : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1_000);
   Result : Files.Interaction.Interaction_Result;
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
      if Files.Model.Settings_Pane.Is_Open (Runtime.Model) then
         --  What Save does with the pane's draft: written, the folder read
         --  again where the change needs it.
         Files.Interaction.Execute_Command
           (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path),
            Files.Commands.Save_Settings_Command, Result => Result);
      else
         --  The pane went: the change is in force, written as it stands.
         Files.Controller.Persist_Settings (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path));
      end if;
   end if;
end Save_Held_Settings;
