--  Test-only mutation helpers for the background-refresh wire format.
package Files.Refresh.Testing is
   --  Expose the production refresh-path invariant to regression tests.
   --  @param Root Requested directory, or empty for Recent.
   --  @param Previous_Path Path retained in the prior directory signature.
   --  @param Recent Whether the request represents the synthetic Recent view.
   --  @return True when the path fields form a valid refresh request.
   function Request_Paths_Are_Valid
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean;

   --  Expose the production native-watch path invariant to regression tests.
   --  @param Path Candidate native-watch path.
   --  @return True when the path is safe to send to the watch helper.
   function Watch_Request_Path_Is_Valid (Path : String) return Boolean;

   --  Replace only the encoded status flags in an otherwise valid result.
   --  @param Path Result record to modify.
   --  @param Success Replacement success flag.
   --  @param Reloaded Replacement reload flag.
   procedure Replace_Result_Flags
     (Path     : String;
      Success  : Boolean;
      Reloaded : Boolean);

   --  Atomically claim a posted watch notification without acknowledging it,
   --  allowing a test to publish the next marker in the race window.
   --  @param Directory Watch transport directory containing the marker.
   --  @return True when a notification was claimed.
   function Claim_Notification (Directory : String) return Boolean;

   --  Attempt to publish one native-watch notification marker.
   --  @param Directory Watch transport directory receiving the marker.
   --  @return True only when the marker was atomically published.
   function Post_Notification (Directory : String) return Boolean;

   --  Return the path retained by a native-watch session.
   --  @param Job Watch session to inspect.
   --  @return Requested path, or empty when the session uses polling fallback.
   function Watch_Target (Job : Watch_Session) return String;

   --  Whether to refresh now for the watch. A change seen while the last
   --  refresh is too recent is owed, and a later call pays it, so the last
   --  write of a burst is always shown.
   --
   --  @param Pacer This window's pacing.
   --  @param Now The current time.
   --  @param Changed The watch reported a change since the last call.
   --  @return True when the caller should refresh now.
   function Watch_Refresh_Due
     (Pacer   : in out Watch_Pacer;
      Now     : Ada.Real_Time.Time;
      Changed : Boolean) return Boolean;

   --  Note a change the watch reported while a refresh is still running: it
   --  stays owed, and Watch_Refresh_Due pays it once that refresh is done
   --  (a read already under way may have listed the folder before it).
   --
   --  @param Pacer This window's pacing.
   --  @param Changed The watch reported a change.
   procedure Owe_Watch_Refresh (Pacer : in out Watch_Pacer; Changed : Boolean);

end Files.Refresh.Testing;
