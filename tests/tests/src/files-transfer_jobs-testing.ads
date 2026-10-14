with Files.File_System;
with Files.Paste;

package Files.Transfer_Jobs.Testing is
   --  Write a transfer request using the production transport format.
   --  @param Path Request file to create.
   --  @param Action Transfer action to encode.
   --  @param Mode Copy or move mode to encode.
   --  @param Batch_Directory Optional shared copy-journal directory.
   procedure Write_Request
     (Path : String;
      Action : Files.Paste.Resolved_Action;
      Mode : Files.File_System.Drop_Import_Mode;
      Batch_Directory : String := "");

   --  Read the action prefix of a production transfer request.
   --  @param Path Request file to inspect.
   --  @return Decoded transfer action.
   function Read_Request_Action
     (Path : String) return Files.Paste.Resolved_Action;

   --  Write a transfer result using the production transport format.
   --  @param Path Result file to create.
   --  @param Result Transfer result to encode.
   procedure Write_Result
     (Path : String;
      Result : Job_Result);

   --  Read a complete production transfer result.
   --  @param Path Result file to inspect.
   --  @return Decoded transfer result.
   function Read_Result (Path : String) return Job_Result;

   --  Return whether a replacement authority checkpoint is accepted by the
   --  production decoder.
   --  @param Path Checkpoint file to inspect.
   --  @return True only for a complete regular record whose identity matches.
   function Replacement_Checkpoint_Is_Valid (Path : String) return Boolean;
end Files.Transfer_Jobs.Testing;
