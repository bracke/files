package body Files.File_System.Transfer.Testing is

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := Files.File_System.Job_Cancelled;
      Batch  : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result
   is
      Created : Created_Entry_Vectors.Vector;
   begin
      return Execute_Drop_Import (Plans, Created, Cancel, Batch);
   end Execute_Drop_Import;

end Files.File_System.Transfer.Testing;
