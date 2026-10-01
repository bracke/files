with Files.Copy_Context;
with Files.Process_Jobs;

with Files.File_System;
with Files.Paste;
with Files.Types;

--  Filesystem-only helpers. Model and rendering state stay on the UI thread.
package Files.Transfer_Jobs is
   type Job_Result is record
      Mutation  : Files.File_System.Mutation_Result := (Success => False, Error_Key => <>);
      Cancelled : Boolean := False;
      Trashed   : Files.Types.UString;
      Trashed_Identity : Files.Types.UString;
      Created_Identity : Files.Types.UString;
      Created_Tree_Revision : Files.Types.UString;
      Recovered : Boolean := False;
   end record;

   type Session is private;

   --  Start one action in a helper, leaving Result collection to Poll.
   --  @param Job Shared, reference-counted helper session.
   --  @param Action Source, destination, and replacement decision.
   --  @param Mode Copy or move mode.
   --  @param Batch Shared hard-link journal owned by the active paste.
   procedure Start
     (Job    : in out Session;
      Action : Files.Paste.Resolved_Action;
      Mode   : Files.File_System.Drop_Import_Mode;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  Collect a completed helper without waiting for filesystem I/O.
   --  @param Job Session to inspect.
   --  @param Finished True when Result is ready.
   --  @param Result Completed action result, or its default while pending.
   procedure Poll (Job : Session; Finished : out Boolean; Result : out Job_Result);

   --  Request cancellation; the helper checks it between file chunks.
   --  @param Job Session to cancel.
   procedure Cancel (Job : Session);

   --  Return whether a session owns a helper.
   --  @param Job Session to inspect.
   --  @return True from Start until Reset.
   function Active (Job : Session) return Boolean;

   --  Release a session; the last owner stops its helper without waiting.
   --  @param Job Session to release.
   procedure Reset (Job : in out Session);

   --  Internal helper entry point; called before application initialization.
   --  @param Directory Private request/result directory.
   procedure Run_Helper (Directory : String);

private
   type Session is record
      Process : Files.Process_Jobs.Session;
   end record;
end Files.Transfer_Jobs;
