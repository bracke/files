--  Test-only access to private subprograms of Files.File_System.Recovery, kept out of the program.
package Files.File_System.Recovery.Testing is

   --  The cross-device half of a move (Files.File_System.Recovery.Move_By_Copy):
   --  copy Source to the new path Destination, then remove Source.
   --  @param Source Entry to move.
   --  @param Destination New pathname; never replaced.
   --  @param Fallback_Key Error key for a failure with no more specific cause.
   --  @param Identity The copy's identity, empty if no copy was published.
   --  @param Revision The copy's tree revision.
   --  @param Copy_Kept Set when, after a failure, the copy is still at Destination.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal of a multi-item job.
   --  @param If_Source_Stays What becomes of the copy when Source cannot be removed.
   --  @param After_Copy Called with Source once the copy is published; null for none.
   --  @param Expected_Identity The identity Source must have, or "" for no check.
   --  @return Success when Destination holds the item and Source is gone.
   function Move_By_Copy
     (Source, Destination : String;
      Fallback_Key        : String;
      Identity, Revision  : out Files.Types.UString;
      Copy_Kept           : out Boolean;
      Cancel              : Cancellation_Check := Job_Cancelled;
      Batch               : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session;
      If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
      After_Copy          : Copy_Hook := null;
      Expected_Identity   : String := "")
      return Mutation_Result;

end Files.File_System.Recovery.Testing;
