package body Files.File_System.Recovery.Testing is

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
      return Mutation_Result
     renames Files.File_System.Recovery.Move_By_Copy;

end Files.File_System.Recovery.Testing;
