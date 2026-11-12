--  The names the program gives its own private files and folders on disk.
--  Several units make, find and clean up the same ones: a name spelled
--  twice could drift, and cleanup would silently stop finding what it owns.
package Files.Protocol_Names is

   --  What a helper's transport folder name starts with (then 32 lower-case
   --  hex digits), directly under the host temporary directory.
   Transport_Prefix : constant String := "files-job-";

   --  The marker that makes a helper's transport folder one.
   Transport_Marker : constant String := ".files-job-transport";

   --  The lease file whose holder owns a transport folder.
   Transport_Lease : constant String := ".files-job-owner";

   --  What every recovery stage's folder name starts with (then a number).
   Recovery_Stage_Prefix : constant String := ".files-recovery-";

   --  The file in a recovery stage that names whose it is.
   Recovery_Owner : constant String := ".files-recovery-owner";

   --  A recovery stage's marker that a restore is moving its payload out;
   --  a stage with it and no payload is finished by removing it.
   Recovery_Vacated : constant String := "vacated";

   --  A recovery stage's marker that a release is moving its payload into
   --  the stage's release folder on the way to the trash.
   Recovery_Releasing : constant String := "releasing";

   --  The files of a helper job's private directory, besides its request and
   --  result (Files.Process_Jobs.Request_File, Result_File). A ".tmp" name is
   --  the staged copy, published whole by renaming it to the plain one.

   --  The window's request that the helper stop.
   Cancel_File : constant String := "cancel";

   --  The folder holding a job's recovery stages.
   Stages_Directory : constant String := "stages";

   --  A transfer's outcome once every item is done.
   Completed_File        : constant String := "completed";
   Staged_Completed_File : constant String := "completed.tmp";

   --  A transfer's checkpoint of the items it replaced so far.
   Replaced_File        : constant String := "replaced";
   Staged_Replaced_File : constant String := "replaced.tmp";

   --  A watch helper's word that it reports every change itself (natively).
   Native_Watch_File : constant String := "native";

   --  A watch helper's change notification, and the name the window claims
   --  it under.
   Changed_File         : constant String := "changed";
   Claimed_Changed_File : constant String := "changed.claimed";

end Files.Protocol_Names;
