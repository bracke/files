--  Test-only mutation helpers for the background-operation wire format.
package Files.Operation_Jobs.Testing is
   --  Expose the production operation-root invariant to regression tests.
   --  @param Root Requested operation directory, or empty for Recent.
   --  @param Recent Whether the request represents the synthetic Recent view.
   --  @return True when Root is valid for the selected view.
   function Request_Path_Is_Valid
     (Root   : String;
      Recent : Boolean) return Boolean;

   --  Replace only the encoded operation kind in an otherwise valid result.
   --  @param Path Result record to modify.
   --  @param Kind Replacement operation kind.
   procedure Replace_Result_Kind
     (Path : String;
      Kind : Operation_Kind);

   --  Replace only the encoded Recent-view flag in an otherwise valid result.
   --  @param Path Result record to modify.
   --  @param Recent Replacement Recent-view flag.
   procedure Replace_Result_Recent
     (Path   : String;
      Recent : Boolean);
end Files.Operation_Jobs.Testing;
