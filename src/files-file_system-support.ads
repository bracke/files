with Ada.Directories;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Interfaces.C;

--  Shared low-level helpers of Files.File_System (safe close / end-search,
--  environment access, small text formatting), extracted so the concern
--  children and the parent can all use them. A private child.
private package Files.File_System.Support is

   --  Enumerate names without following links or dropping dangling links.
   --  @param Path Directory to read.
   --  @param Visit Called for each entry other than dot and dot-dot.
   procedure For_Each_Entry
     (Path : String; Visit : not null access procedure (Name : String));

   --  End a directory search, swallowing any exception and doing nothing when
   --  it was never started; Started is reset to False.
   --
   --  @param Search The directory search to end.
   --  @param Started Whether Search was started; set to False.
   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean);

   --  Close a text file if it is open, ignoring any error from the close.
   --
   --  @param File The text file to close.
   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   --  Close a stream file if it is open, ignoring any error from the close.
   --
   --  @param File The stream file to close.
   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type);

   --  The value of environment variable Name, or "" when it is unset or cannot
   --  be read.
   --
   --  @param Name Environment variable name.
   --  @return Its value, or "" when unset/unreadable.
   function Safe_Environment_Value
     (Name : String)
      return String;

   --  Whether environment variable Name equals Expected, compared
   --  case-insensitively.
   --
   --  @param Name Environment variable name.
   --  @param Expected Value to compare against.
   --  @return True when the variable's value equals Expected.
   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

   --  Natural'Image with the leading space GNAT prefixes to a non-negative
   --  number stripped.
   --
   --  @param Value Number to format.
   --  @return Value's decimal text, without a leading space.
   function Image_No_Space (Value : Natural) return String;

   --  Whether Value begins with Prefix.
   --
   --  @param Value String to test.
   --  @param Prefix Candidate leading substring.
   --  @return True when Value starts with Prefix.
   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean;

   --  Decimal text of Value: Natural'Image with the leading space guarded off.
   --
   --  @param Value Number to format.
   --  @return Value's decimal text, without a leading space.
   function Natural_Text (Value : Natural) return String;

   --  @param Parent Existing directory on the destination filesystem.
   --  @return Exclusively created, journaled private staging directory.
   function Create_Stage (Parent : String) return String;

   type Copy_Times is array (Positive range 1 .. 4) of Interfaces.C.long_long
     with Convention => C;
   package Source_Time_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Copy_Times);

   type Source_Snapshot is record
      Root_Revision : Files.Types.UString;
      Entries : Files.Types.String_Vectors.Vector;
      Times : Source_Time_Maps.Map;
   end record;

   --  Verification excludes access times changed by reading the source.
   --  @param Left Original identity and revision snapshot.
   --  @param Right Snapshot to compare with the original.
   --  @return True when identities and revisions match.
   overriding function "=" (Left, Right : Source_Snapshot) return Boolean;

   --  Move without replacement, restoring a read-only directory's owner mode.
   --  @param Source Source entry to rename.
   --  @param Destination New destination pathname.
   --  @return True when the rename succeeded; False leaves the source in place.
   function Move_No_Replace (Source, Destination : String) return Boolean;

   type Copied_File is record
      Path, Identity, Source_Revision, Destination_Revision, Content_Digest : Files.Types.UString;
   end record;
   package Copied_File_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Copied_File);

   --  @param Batch Batch journal to load.
   --  @return Verified source-to-destination records for this batch.
   function Load_Links (Batch : Files.Copy_Context.Session) return Copied_File_Maps.Map;

   --  @param Batch Batch journal to update.
   --  @param Links Source identity records, including this newly published root.
   --  @param Stage Private payload prefix to replace after publication.
   --  @param Destination Published payload prefix.
   procedure Save_Links
     (Batch : Files.Copy_Context.Session; Links : Copied_File_Maps.Map; Stage, Destination : String);

   --  Copy privately and publish atomically without replacing an existing entry.
   --  @param Source_Path Source file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Cancel Optional cooperative cancellation callback.
   --  @param Preserve_Ownership Require original ownership before publishing a move.
   --  @param Batch Shared journal for hard links across copied roots.
   procedure Copy_To_New_Path
     (Source_Path : String; Destination_Path : String; Cancel : Cancellation_Check := null;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  @param Source_Path Source file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Identity Identity captured before publishing the new destination.
   --  @param Cancel Optional cooperative cancellation callback.
   --  @param Preserve_Ownership Require original ownership before publishing a move.
   --  @param Batch Shared journal for hard links across copied roots.
   --  @param Times Source times captured before a move's verification traversal.
   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  Copy and return identity plus a directory or regular-file revision.
   --  @param Source_Path Existing file, directory, or symbolic link.
   --  @param Destination_Path New destination pathname.
   --  @param Identity Identity captured in private staging before publication.
   --  @param Tree_Revision_Value Stable revision captured before publication; empty for links.
   --  @param Cancel Optional cooperative cancellation callback.
   --  @param Times Source times captured before verification reads the source.
   --  @param Preserve_Ownership Require original ownership before publishing a move.
   --  @param Batch Shared journal for hard links across copied roots.
   procedure Copy_To_New_Path
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Cancel : Cancellation_Check := null;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  @param Path Source tree to snapshot without following links.
   --  @return Sorted identities, revisions, and regular-file content digests,
   --    raising if any entry cannot be verified.
   function Snapshot (Path : String) return Source_Snapshot;

   --  @param Path Existing entry to inspect without following symbolic links.
   --  @return SHA-256 of a directory's recursive metadata and file contents;
   --    stable metadata and a SHA-256 content digest for a regular file; or
   --    empty for a link or unsupported or unreadable entry.
   --    Raises when a directory cannot be completely verified.
   function Tree_Revision (Path : String) return String;

   --  Recursively copy a file or directory tree from Source_Path to
   --  Destination_Path (Depth guards against symlink cycles). The shared
   --  worker behind the public Copy_Tree function and the cross-device
   --  trash/restore fallbacks.
   --
   --  @param Source_Path Source file or directory.
   --  @param Destination_Path Destination path to create.
   --  @param Depth Current recursion depth (0 at the top).
   --  @param Cancel Optional callback checked between entries and file chunks.
   --  @param Check_Job_Cancellation False for recovery that must finish after cancellation.
   --  @param Times Optional times captured before verification reads the source.
   --  @param Preserve_Ownership Require original ownership for a copy-based move.
   --  @param Batch Shared journal for hard links across copied roots.
   procedure Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Depth            : Natural := 0;
      Cancel           : Cancellation_Check := null;
      Check_Job_Cancellation : Boolean := True;
      Times : Source_Time_Maps.Map := Source_Time_Maps.Empty_Map;
      Preserve_Ownership : Boolean := False;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session);

   --  Recursively delete a file, directory, or symlink. A symlink -- even one
   --  whose target is a directory -- is unlinked as a link and never followed,
   --  so deleting a link (or a folder that merely contains one) can never
   --  reach through into the link target's real contents. This is the safe
   --  replacement for Ada.Directories.Delete_Tree, which follows links; it
   --  mirrors Copy_Tree's link handling.
   --
   --  @param Path File, directory, or symlink to remove.
   procedure Delete_Tree (Path : String);

   --  Remove a private or identity-verified owned copy, releasing directory
   --  write restrictions preserved from its source. Never follows symlinks.
   --  @param Path Private or identity-verified owned entry to remove.
   procedure Delete_Owned_Tree (Path : String);

   --  Shared Interfaces.C aliases for the native (statvfs / gdk-pixbuf) bindings.
   subtype C_Int is Interfaces.C.int;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;
   subtype C_Size is Interfaces.C.size_t;
   subtype C_ULong is Interfaces.C.unsigned_long;
   subtype C_Char is Interfaces.C.char;
   type U64_Array is array (Positive range <>) of C_U64
     with Convention => C;

end Files.File_System.Support;
