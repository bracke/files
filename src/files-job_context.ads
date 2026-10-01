with Files.Types;
with Files.Job_Transports;

--  Helper-local cancellation and staging journal. Never set by the UI process.
package Files.Job_Context is
   --  @param Directory Private helper transport directory, or empty outside a helper.
   procedure Initialize (Directory : String);

   --  Release the process-wide foreground staging owner before the orphan
   --  reaper stops, so its finalization cannot queue work after shutdown.
   procedure Shutdown;

   --  @return Private transport directory, or empty outside a helper.
   function Directory return String;

   --  @return True when this helper's parent requested cancellation.
   function Cancelled return Boolean;

   --  Create a directory with owner-only access before creating any payload.
   --  @param Path Unused directory pathname; raises on failure or collision.
   procedure Create_Private_Directory (Path : String);

   --  @param Parent Destination filesystem directory.
   --  @return Exclusively created and journaled staging directory.
   --  Raises Use_Error before copying when the filesystem cannot identify the
   --  directory without a copyable sidecar (for example, no birth time).
   function Create_Stage (Parent : String) return String;

   --  @param Destination Published complete file or directory.
   --  @param Source Source pathname, or empty for archives and extraction.
   --  Journal failures cannot undo publication; they do not raise. The normal
   --  operation result still records completion and retains Undo.
   procedure Record_Created (Destination : String; Source : String := "");

   --  @param Destination Published complete output pathname.
   --  @param Source Source pathname, or empty for archives and extraction.
   --  @param Identity Identity captured in private staging before publication; empty fails closed.
   procedure Record_Created (Destination, Source, Identity : String);

   --  @param Destination Published complete output pathname.
   --  @param Source Source pathname, or empty for archives and extraction.
   --  @param Identity Identity captured in private staging before publication.
   --  @param Tree_Revision Recursive directory revision captured before publication.
   procedure Record_Created (Destination, Source, Identity, Tree_Revision : String);

   --  @param Directory Helper transport directory containing the publication journal.
   --  @param Destinations Published complete output pathnames.
   --  @param Sources Parallel source pathnames.
   --  @param Identities Parallel identities captured at publication, never during recovery.
   --  @param Tree_Revisions Parallel recursive directory revisions captured at publication.
   procedure Read_Created
     (Directory : String;
      Destinations : out Files.Types.String_Vectors.Vector;
      Sources : out Files.Types.String_Vectors.Vector;
      Identities : out Files.Types.String_Vectors.Vector;
      Tree_Revisions : out Files.Types.String_Vectors.Vector);

   --  Record a move only after its source has been vacated.
   --  @param Destination Committed destination pathname.
   --  @param Source Original source pathname.
   --  @param Identity Destination identity retained from publication.
   procedure Record_Moved (Destination, Source, Identity : String);

   --  @param Directory Helper transport directory containing committed moves.
   --  @param Destinations Committed destination pathnames.
   --  @param Sources Parallel original source pathnames.
   --  @param Identities Parallel destination identities retained at publication.
   procedure Read_Moved
     (Directory : String;
      Destinations, Sources, Identities : out Files.Types.String_Vectors.Vector);

   --  Remove a stage created by this process after checking the identity stored
   --  in its private owner marker. Foreground failures release their managed
   --  journal to the cleanup helper for retry.
   --  @param Path Staging directory returned by Create_Stage.
   --  @return True when the stage is absent or its verified tree was removed.
   function Discard_Stage (Path : String) return Boolean;

   --  Clean independent write-ahead records while holding this transport's lease.
   --  @param Directory Transport directory containing the stage records.
   --  @param Owner Live owner or exclusive abandoned-transport claim.
   --  @param Discard_Unreadable Drop private records that still cannot be
   --         opened after their caller has exhausted its bounded retries.
   procedure Clean_Stages
     (Directory          : String;
      Owner              : Files.Job_Transports.Lease;
      Discard_Unreadable : Boolean := False);
private
   Current : Files.Types.UString;
end Files.Job_Context;
