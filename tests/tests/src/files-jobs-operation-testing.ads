--  Test-only mutation helpers for the background-operation wire format.
package Files.Jobs.Operation.Testing is
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

   --  Make the next finished operation fail after its journal is merged and
   --  its undo recovered, as if its view work had raised -- first recording
   --  one creation of Recording, as an untracked creation is recorded then.
   --  Stays armed until Stop_Failing_After_Merge.
   --  @param Recording Path of an existing file to record as created.
   procedure Fail_After_Merge (Recording : String);

   --  Disarm Fail_After_Merge.
   procedure Stop_Failing_After_Merge;
end Files.Jobs.Operation.Testing;
