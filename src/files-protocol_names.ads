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

   --  What every private copy stage's folder name starts with (then a
   --  number): the folder a copy or move writes into beside its destination
   --  before it is published under its own name.
   Work_Stage_Prefix : constant String := ".files-work-";

   --  What every recovery stage's folder name starts with (then a number).
   Recovery_Stage_Prefix : constant String := ".files-recovery-";

   --  The file in the recovery registry that every process changing the
   --  registry holds an advisory lock on, so one never removes a slot
   --  another has just claimed.
   Recovery_Registry_Lock : constant String := ".files-registry-lock";

   --  The file in a recovery stage that names whose it is.
   Recovery_Owner : constant String := ".files-recovery-owner";

   --  The file in a job's work stage that names the job directory owning it,
   --  and the header that record starts with.
   Stage_Owner_File   : constant String := ".files-owner";
   Stage_Owner_Header : constant String := "files-stage-owner-1";

   --  A recovery stage's marker that a restore is moving its payload out;
   --  a stage with it and no payload is finished by removing it.
   Recovery_Vacated : constant String := "vacated";

   --  A recovery stage's marker that a release is moving its payload into
   --  the stage's release folder on the way to the trash.
   Recovery_Releasing : constant String := "releasing";

   --  The entry a work or recovery stage holds: what a copy writes before it
   --  is published, or what a recovery stage keeps.
   Stage_Payload : constant String := "payload";

   --  A recovery stage's record of the original path of its payload.
   Recovery_Original : constant String := "original";

   --  A recovery stage's record of its payload's permission bits.
   Recovery_Mode : constant String := "mode";

   --  A recovery registry slot's record of the stage it names.
   Recovery_Record : constant String := "record";

   --  A recovery stage's folder that a release moves the payload into on its
   --  way to the trash.
   Recovery_Release : constant String := "release";

   --  The files of a helper job's private directory, besides its request and
   --  result (Files.Jobs.Process.Request_File, Result_File). A ".tmp" name is
   --  the staged copy (Files.Jobs.Process.Staged_Name), published whole by
   --  renaming it to the plain one.

   --  The window's request that the helper stop.
   Cancel_File : constant String := "cancel";

   --  The folder holding a job's recovery stages.
   Stages_Directory : constant String := "stages";

   --  A transfer's outcome once every item is done.
   Completed_File : constant String := "completed";

   --  A transfer's checkpoint of the items it replaced so far.
   Replaced_File : constant String := "replaced";

   --  A watch helper's word that it reports every change itself (natively).
   Native_Watch_File : constant String := "native";

   --  A watch helper's change notification, and the name the window claims
   --  it under.
   Changed_File         : constant String := "changed";
   Claimed_Changed_File : constant String := "changed.claimed";

   --  The folder under the per-user application data directory that holds
   --  files' own data (Files.File_System.Support.Files_Data_Directory).
   Data_Folder : constant String := "files";

   --  In it: the list of volume trashes the trash view also lists, one
   --  absolute path per line, and the recovery index folder.
   Volume_Trash_List     : constant String := "volume-trashes";
   Recovery_Index_Folder : constant String := "recovery-index";

end Files.Protocol_Names;
