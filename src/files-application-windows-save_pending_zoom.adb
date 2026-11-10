with Files.Timing;
separate (Files.Application.Windows)
--  Save a wheel zoom once the wheel has rested, or with Force at once (a
--  window closing); nothing when none is pending.
procedure Save_Pending_Zoom (Runtime : in out Runtime_Window; Force : Boolean) is
   --  Long enough to cover a pinch or a fast wheel spin.
   Zoom_Save_Delay : constant Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (500);
begin
   if Runtime.Zoom_Unsaved
     and then (Force or else Files.Timing.Elapsed (Ada.Real_Time.Clock, Runtime.Zoom_At, Zoom_Save_Delay))
   then
      Runtime.Zoom_Unsaved := False;
      Files.Controller.Persist_Settings (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path));
   end if;
end Save_Pending_Zoom;
