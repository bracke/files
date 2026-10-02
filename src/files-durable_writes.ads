with Hostkit.Durability;

--  Crash-safe publication of a completely written temporary file.
package Files.Durable_Writes is
   type Publication_Result is
     (Not_Published,
      Published_Not_Durable,
      Published_Durable);

   --  Sync Temporary, atomically replace Target, then sync Target's directory.
   --  Directory syncing may be unsupported on hosts that journal directory
   --  entries themselves; an explicit failure is never accepted.
   --  @param Temporary Complete file to sync and publish.
   --  @param Target Destination atomically replaced by Temporary.
   --  @return Whether publication did not happen, happened without a confirmed
   --    directory sync, or completed durably. A caller must not retry a
   --    Published_Not_Durable write as though Target were unchanged.
   function Publish (Temporary, Target : String) return Publication_Result;

   --  @param Result Publication outcome to inspect.
   --  @return True when Target was replaced, even if directory sync failed.
   function Published (Result : Publication_Result) return Boolean is
     (Result /= Not_Published);

   --  @param Result Publication outcome to inspect.
   --  @return True when publication reached the host's durability boundary.
   function Durable (Result : Publication_Result) return Boolean is
     (Result = Published_Durable);

private
   function Outcome_Of
     (File_Sync      : Hostkit.Durability.Outcome;
      Replaced       : Boolean;
      Directory_Sync : Hostkit.Durability.Outcome)
      return Publication_Result;
end Files.Durable_Writes;
