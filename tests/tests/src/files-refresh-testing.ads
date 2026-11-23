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

   --  Replace only the encoded status flags in an otherwise valid result.
   --  @param Path Result record to modify.
   --  @param Success Replacement success flag.
   --  @param Reloaded Replacement reload flag.
   procedure Replace_Result_Flags
     (Path     : String;
      Success  : Boolean;
      Reloaded : Boolean);

end Files.Refresh.Testing;
