with Files.Process_Jobs;
with Files.Types;

--  Private batch journal shared by consecutive copy helpers and history retries.
package Files.Copy_Context is
   type Session is private;
   Empty_Session : constant Session;

   --  @return A reference-counted private batch directory.
   function Create return Session;

   --  @param Batch Copy batch, or the empty session.
   --  @return Private directory, or empty for an isolated copy.
   function Directory (Batch : Session) return String;

   --  @param Batch Batch whose verified hard-link records to read.
   --  @return Serialized source identity/revision/content digest and destination path/identity/revision groups.
   function Records (Batch : Session) return Files.Types.String_Vectors.Vector;

   --  @param Batch Batch that owns the journal.
   --  @param Items Verified hard-link records to publish atomically.
   procedure Save (Batch : Session; Items : Files.Types.String_Vectors.Vector);
   --  @param Path Parent-owned batch directory borrowed by a copy helper.
   --  @return A non-owning view of its copy journal.
   function Borrow (Path : String) return Session;
private
   type Session is record
      Job : Files.Process_Jobs.Session;
      Borrowed : Files.Types.UString;
   end record;
   Empty_Session : constant Session := (others => <>);
end Files.Copy_Context;
