--  The four verified filesystem operations the job layer (Files.Job_Context,
--  Files.Process_Jobs) needs, supplied by Files.File_System.
--
--  The job layer -- cancellation, the staging and move journal, helper
--  transports -- sits below Files.File_System: the copy engine writes the
--  journal and asks for cancellation as it works. Removing a stage or a
--  transport, and checking a recorded creation, are the file system's own
--  quarantine and identity work, so the job layer reaches them through this
--  port instead of naming Files.File_System. Files.File_System installs its
--  operations when its body is elaborated; until then each call raises
--  Program_Error rather than quietly doing nothing.
package Files.Job_Storage is

   --  @param Path Entry to remove.
   --  @param Expected_Identity Identity captured when it was created.
   --  @return True only when the verified entry was removed.
   type Delete_Operation is access function (Path, Expected_Identity : String) return Boolean;

   --  @param Path Created entry to check.
   --  @param Identity Identity recorded when it was created.
   --  @param Tree_Revision Tree revision recorded then; empty for a link.
   --  @param Retain_Verified Accept an entry verified once whose identity
   --    has since changed.
   --  @return True when Path is still the created entry.
   type Creation_Check is access function
     (Path, Identity, Tree_Revision : String; Retain_Verified : Boolean) return Boolean;

   --  @param Path Existing entry to inspect without following links.
   --  @return Its tree revision, or empty when it cannot be verified.
   type Revision_Query is access function (Path : String) return String;

   --  Install the file system's operations. Called once, by Files.File_System.
   --  @param Delete_Staging Files.File_System.Delete_Staging_Entry.
   --  @param Delete_Transport Files.File_System.Delete_Transport_Entry.
   --  @param Matches Files.File_System.Creation_Matches.
   --  @param Revision Files.File_System.Tree_Revision.
   procedure Install
     (Delete_Staging   : not null Delete_Operation;
      Delete_Transport : not null Delete_Operation;
      Matches          : not null Creation_Check;
      Revision         : not null Revision_Query);

   --  Quarantine and remove a private staging tree by its root identity
   --  (Files.File_System.Delete_Staging_Entry).
   --  @param Path Staging directory.
   --  @param Expected_Identity Root identity captured at stage creation.
   --  @return True only when the verified stage was removed.
   function Delete_Staging_Entry (Path, Expected_Identity : String) return Boolean;

   --  Remove a helper transport by its identity
   --  (Files.File_System.Delete_Transport_Entry).
   --  @param Path Transport directory.
   --  @param Expected_Identity Identity captured when it was created.
   --  @return True only when the transport is gone.
   function Delete_Transport_Entry (Path, Expected_Identity : String) return Boolean;

   --  Whether Path is still exactly what an operation created
   --  (Files.File_System.Creation_Matches).
   --  @param Path Created entry to check.
   --  @param Identity Identity token recorded when it was created.
   --  @param Tree_Revision Tree revision recorded then; empty for a link.
   --  @param Retain_Verified Accept an entry verified once whose identity has
   --    since changed.
   --  @return True when Path is still the created entry.
   function Creation_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean;

   --  @param Path Existing entry (Files.File_System.Tree_Revision).
   --  @return Its tree revision, or empty for a link or unverifiable entry.
   function Tree_Revision (Path : String) return String;

end Files.Job_Storage;
