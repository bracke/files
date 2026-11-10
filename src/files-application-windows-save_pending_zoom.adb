with Files.Window_Policy;
separate (Files.Application.Windows)
--  Save a wheel zoom once the wheel has rested, or with Force at once (a
--  window closing); nothing when none is pending.
procedure Save_Pending_Zoom (Runtime : in out Runtime_Window; Force : Boolean) is
begin
   if Files.Window_Policy.Zoom_Save_Due (Runtime.Zoom_Unsaved, Force, Ada.Real_Time.Clock, Runtime.Zoom_At) then
      Runtime.Zoom_Unsaved := False;
      Files.Controller.Persist_Settings (Runtime.Model, Runtime.Settings, To_String (Runtime.Settings_Path));
   end if;
end Save_Pending_Zoom;
