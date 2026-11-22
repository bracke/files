package body Files.Application.Event_Wait.Testing is

   function Window_Wait
     (Now     : Ada.Real_Time.Time;
      Pending : Window_Pending;
      Limit   : Duration;
      Prompt  : Duration)
      return Duration renames Files.Application.Event_Wait.Window_Wait;

end Files.Application.Event_Wait.Testing;
