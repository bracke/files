with Ada.Strings.Unbounded;

package body Files.Refresh.Watch.Testing is

   function Watch_Request_Path_Is_Valid (Path : String) return Boolean is
     (Watch_Path_Is_Consistent (Path));

   function Claim_Notification (Directory : String) return Boolean is
     (Claim_Watch_Notification (Directory));

   function Post_Notification (Directory : String) return Boolean is
     (Post_Watch_Notification (Directory));

   function Watch_Target (Job : Watch_Session) return String is
     (Ada.Strings.Unbounded.To_String (Job.Path));

   function Watch_Refresh_Due
     (Pacer   : in out Watch_Pacer;
      Now     : Ada.Real_Time.Time;
      Changed : Boolean) return Boolean renames Files.Refresh.Watch.Watch_Refresh_Due;

   procedure Owe_Watch_Refresh (Pacer : in out Watch_Pacer; Changed : Boolean)
     renames Files.Refresh.Watch.Owe_Watch_Refresh;

   function Retry_Due
     (Pacer       : in out Watch_Pacer;
      Now         : Ada.Real_Time.Time;
      Load_Failed : Boolean) return Boolean renames Files.Refresh.Watch.Retry_Due;

end Files.Refresh.Watch.Testing;
