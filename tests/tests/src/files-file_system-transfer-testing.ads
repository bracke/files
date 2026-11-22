--  Test-only access to Files.File_System.Transfer's private engine.
package Files.File_System.Transfer.Testing is

   --  Execute validated drag-and-drop import plans, as Import_Replacing does
   --  for one: production imports one plan at a time, the suite drives
   --  several.
   --
   --  @param Plans Plans produced by Plan_Drop_Import.
   --  @param Cancel Checked before source deletion: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal, created automatically for multiple plans.
   --  @return Mutation result with a localized error key on failure.
   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := Files.File_System.Job_Cancelled;
      Batch  : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

end Files.File_System.Transfer.Testing;
