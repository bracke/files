with Ada.Containers.Vectors;
with Files.Types;
with Files.Job_Transports;

--  Cancellation and the staging journal, for whichever process is copying.
--  Process-wide state, one instance per process, in two modes:
--
--  * In a job helper, Initialize names the private transport directory the
--    parent handed it; cancellation and the journal of created stages are
--    read from and written there.
--  * In the UI process, Initialize is never called (Directory stays empty,
--    Cancelled stays False), and a stage created by a foreground operation is
--    journaled under a reserved job directory instead, so a stage it fails to
--    discard is handed to the cleanup helper for retry. Shutdown releases it.
package Files.Job_Context is
   --  @param Directory Absolute private helper transport directory, or empty
   --    outside a helper.
   --  @exception Ada.Directories.Use_Error when a nonempty path is invalid.
   procedure Initialize (Directory : String);

   --  Release the process-wide foreground staging owner before the orphan
   --  reaper stops, so its finalization cannot queue work after shutdown.
   procedure Shutdown;

   --  @return Private transport directory, or empty outside a helper.
   function Directory return String;

   --  Whether this helper's parent requested cancellation: the one check
   --  every helper's work stops for (Files.File_System.Job_Cancelled). Cheap
   --  enough to ask for every chunk copied: the marker is read at most every
   --  100 ms, and once seen a cancel stays seen.
   --  @return True once this helper's parent requested cancellation.
   function Cancelled return Boolean;

   --  @param Parent Absolute destination filesystem directory.
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

   --  One entry a helper's journal records: published (Record_Created) or
   --  moved into place (Record_Moved).
   type Journal_Entry is record
      --  Where it is now, and where it came from (empty for an archive or an
      --  extraction).
      Destination   : Files.Types.UString;
      Source        : Files.Types.UString;
      --  Its identity captured at publication, never during recovery.
      Identity      : Files.Types.UString;
      --  A created directory's recursive revision at publication; empty for
      --  a file, a link, and every move.
      Tree_Revision : Files.Types.UString;
   end record;

   package Journal_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Journal_Entry);

   --  Say, before Destination is published from staging, what is about to
   --  be: a helper stopped between the publication and Record_Created still
   --  has the entry found (Read_Created), by the identity it carries. Its own
   --  journal beside the one Record_Created writes, so a journal from before
   --  intents were kept reads as it always did.
   --  @param Destination Pathname about to be published.
   --  @param Source Source pathname, or empty for archives and extraction.
   --  @param Identity Identity captured in private staging before publication.
   --  @param Tree_Revision Revision captured in staging before publication.
   --  A publication whose revision changed once it was in place (a folder
   --  whose new parent's access, inherited on Windows, rewrote its change
   --  times) names it again with the revision it has now: of several
   --  intents for one destination, the latest that was carried out counts.
   procedure Intend_Created (Destination, Source, Identity, Tree_Revision : String);

   --  @param Directory Helper transport directory containing the publication journal.
   --  @return The published entries, in order; those before a damaged record
   --    when one is. Then each one an intent named (Intend_Created) that was
   --    published but not yet recorded: Destination carries its identity,
   --    which is the check; of several intents for one destination, the
   --    latest so published.
   function Read_Created (Directory : String) return Journal_Entry_Vectors.Vector;

   --  Record a move only after its source has been vacated.
   --  @param Destination Committed destination pathname.
   --  @param Source Original source pathname.
   --  @param Identity Destination identity retained from publication.
   procedure Record_Moved (Destination, Source, Identity : String);

   --  Say, before Source is moved to Destination, what is about to move: a
   --  helper stopped between the move and Record_Moved still has it found
   --  (Read_Moved). Its own journal, as Intend_Created's is.
   --  @param Destination Pathname the entry is about to move to.
   --  @param Source Pathname it moves from.
   --  @param Identity The entry's identity, which a rename keeps.
   procedure Intend_Moved (Destination, Source, Identity : String);

   --  @param Directory Helper transport directory containing committed moves.
   --  @return The committed moves, in order; those before a damaged record
   --    when one is. Then each one an intent named (Intend_Moved) that
   --    happened but was not yet recorded: Destination carries its identity
   --    and Source is gone for sure.
   function Read_Moved (Directory : String) return Journal_Entry_Vectors.Vector;

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
