--  The names the program gives its own private files and folders on disk.
--  Several units make, find and clean up the same ones: a name spelled
--  twice could drift, and cleanup would silently stop finding what it owns.
package Files.Protocol_Names is

   --  The marker that makes a helper's transport folder one.
   Transport_Marker : constant String := ".files-job-transport";

   --  The lease file whose holder owns a transport folder.
   Transport_Lease : constant String := ".files-job-owner";

   --  What every recovery stage's folder name starts with (then a number).
   Recovery_Stage_Prefix : constant String := ".files-recovery-";

   --  The file in a recovery stage that names whose it is.
   Recovery_Owner : constant String := ".files-recovery-owner";

end Files.Protocol_Names;
