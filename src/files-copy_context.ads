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

   --  One verified hard link a copy batch has made: the source file it
   --  copied and the destination file later sources sharing that identity
   --  are linked to.  The journal stores each record as Fields_Per_Record
   --  consecutive strings, in the order of the components below.
   type Copy_Record is record
      Source_Identity      : Files.Types.UString;
      Source_Revision      : Files.Types.UString;
      Content_Digest       : Files.Types.UString;
      Destination_Path     : Files.Types.UString;
      Destination_Identity : Files.Types.UString;
      Destination_Revision : Files.Types.UString;
   end record;

   --  How many journal strings one Copy_Record occupies.
   Fields_Per_Record : constant := 6;

   --  Whether Item can be trusted: every field present and NUL-free, and
   --  the destination an absolute path.
   --
   --  @param Item Record to check.
   --  @return True when Item is well formed.
   function Valid (Item : Copy_Record) return Boolean;

   --  @param Items Serialized records.
   --  @return True when Items is whole records, each Valid, with no source
   --    identity twice.
   function Valid (Items : Files.Types.String_Vectors.Vector) return Boolean;

   --  @param Item Record to serialize.
   --  @param Into Journal strings Item is appended to.
   procedure Encode (Item : Copy_Record; Into : in out Files.Types.String_Vectors.Vector);

   --  @param Items Serialized records.
   --  @param Position One-based record number, at most Record_Count (Items).
   --  @return The record at Position, unchecked; ask Valid first.
   function Decode (Items : Files.Types.String_Vectors.Vector; Position : Positive) return Copy_Record;

   --  @param Items Serialized records.
   --  @return How many whole records Items holds.
   function Record_Count (Items : Files.Types.String_Vectors.Vector) return Natural is
     (Natural (Items.Length) / Fields_Per_Record);

   --  @param Batch Batch whose verified hard-link records to read.
   --  @return Serialized source identity/revision/content digest and destination path/identity/revision groups.
   function Records (Batch : Session) return Files.Types.String_Vectors.Vector;

   --  @param Batch Batch that owns the journal.
   --  @param Items Verified hard-link records to publish atomically.
   procedure Save (Batch : Session; Items : Files.Types.String_Vectors.Vector);
   --  @param Path Absolute parent-owned batch directory borrowed by a copy helper.
   --  @return A non-owning view of its copy journal.
   --  @exception Ada.Directories.Use_Error when Path is empty, relative, too
   --    long, or contains NUL.
   function Borrow (Path : String) return Session;
private
   type Session is record
      Job : Files.Process_Jobs.Session;
      Borrowed : Files.Types.UString;
   end record;
   Empty_Session : constant Session := (others => <>);
end Files.Copy_Context;
