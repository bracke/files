with Files.Extra_Info;

with Files.File_Types;
with Files.Items;
with Files.Types;
with Files.File_System_Types;

--  Filesystem inspection, directory loading, and mutation result modeling.
package Files.File_System is
   subtype UString is Files.Types.UString;

   --  The value types this package's subprograms take and return (path
   --  status, signatures, drop modes, roots) live in Files.File_System_Types,
   --  so a unit that only holds them need not depend on this package; clients
   --  name them there. They are made directly visible to this package and its
   --  children here.
   use Files.File_System_Types;

   --  The item type is Files.Items'; these names keep it at hand here.
   subtype Directory_Item is Files.Items.Directory_Item;
   package Item_Vectors renames Files.Items.Item_Vectors;

   --  The signature of a listing not read from the directory (search
   --  results, items handed in) or one that could not be signed: the next
   --  check of Path reads it again.
   --
   --  @param Path The directory it stands for.
   --  @return A signature that was not taken.
   function Unknown_Signature (Path : String := "") return Directory_Signature;

   --  Whether two signatures were both taken and record the same state. An
   --  unknown signature is the same as nothing, itself included.
   --
   --  @param Left One signature.
   --  @param Right The other.
   --  @return True when nothing changed between them.
   function Same_State (Left, Right : Directory_Signature) return Boolean;

   --  Signature: the directory's change signature, taken while it was
   --  listed, when the load was asked for one (Load_Directory_Deferring_Thumbnails);
   --  otherwise, or when it could not be taken, one that never matches.
   type Directory_Load_Result is record
      Success   : Boolean := False;
      Path      : UString;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
      Signature : Directory_Signature;
   end record;

   type Directory_Change_Result is record
      Changed        : Boolean := False;
      Before_State   : Directory_Signature;
      After_State    : Directory_Signature;
      Error_Key      : UString;
   end record;

   type Mutation_Result is record
      Success   : Boolean := False;
      Error_Key : UString;
   end record;

   --  Normalize an existing filesystem path to a directory path.
   --
   --  @param Path Path supplied by a user or command line.
   --  @return Path validation result and normalized directory path when valid.
   function Normalize_Path
     (Path : String)
      return Path_Result;

   --  Expand a leading "~" or "~/" in a user-typed path against $HOME, the way a
   --  shell does, so the path field accepts "~", "~/Downloads", etc. A "~" that
   --  is not the whole path or its first component is left alone (it can be a
   --  real filename), and when $HOME is unset the path is returned unchanged.
   --
   --  @param Path Path as typed by the user.
   --  @return Path with a leading tilde expanded to the home directory.
   function Expand_User_Path (Path : String) return String;

   --  Load the direct children of a directory. Thumbnails come from the cache
   --  only: no image is decoded and no cache file written, so a caller that
   --  discards the items (a search walk, emptying the Trash) pays nothing for
   --  them. Load_Directory_Generating_Thumbnails is the variant that makes them.
   --
   --  @param Path Directory path to load.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy (Files.Settings.Listing_Options_Of).
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result;

   --  Load_Directory that also decodes each image lacking a cached thumbnail
   --  and writes its cache file. Slow on a folder of new photos, so it is for
   --  the background listing (Files.Refresh), not a read the UI waits on.
   --
   --  @param Path Directory path to load.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy (Files.Settings.Listing_Options_Of).
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory_Generating_Thumbnails
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result;

   --  Load only the entries Include accepts (null accepts all); the others
   --  are skipped after a cheap kind check, so a caller that wants one kind,
   --  such as the folder tree's subdirectories, does not stat, classify and
   --  thumbnail every file it passes.
   --
   --  Every load applies the listing policy it is given as Options and
   --  classifies items by Classes; none reads the settings record itself.
   --
   --  @param Path Directory path to load.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy for the listing.
   --  @param Include Entry filter, or null for every entry.
   --  @param Name Entry name Include is asked about.
   --  @param Kind Entry kind Include is asked about.
   --  @param Generate_Thumbnails Whether to decode images lacking a cached thumbnail.
   --  @param With_Signature Whether to take the directory's change signature
   --    in the same pass (Path's own entries, hidden or not, before Include).
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory_Filtered
     (Path     : String;
      Classes  : Files.File_Types.Classification;
      Options  : Files.Types.Listing_Options;
      Include  : access function
        (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Generate_Thumbnails : Boolean := False;
      With_Signature      : Boolean := False)
      return Directory_Load_Result;

   --  Load_Directory for a listing the UI waits on: thumbnails come from the
   --  cache only, and generating the missing ones -- decoding every new photo
   --  of a camera folder -- is left to a background listing. The result
   --  carries the directory's signature, taken in the same pass, so a file
   --  created during the load is either listed or seen as a change.
   --
   --  @param Path Directory path to load.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy (Files.Settings.Listing_Options_Of).
   --  @return Directory load result.
   function Load_Directory_Deferring_Thumbnails
     (Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options)
      return Directory_Load_Result;

   --  Path's subdirectories, for the folder tree, in the listing's sort
   --  order, read lean: an entry's kind comes from the directory listing
   --  (Hostkit.Directory_Listing; one no-follow stat only where it does not
   --  record it), and a subfolder is dated or classified only when the sort
   --  reads it (by date, by type). A full listing took 200 ms for 22,000
   --  entries. A link to a folder is not a subdirectory.
   --
   --  @param Path Directory whose subdirectories are listed.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @param Options Hidden-entry and sort policy.
   --  @return The subdirectories, or a recoverable error result.
   function Load_Subdirectories
     (Path     : String;
      Classes  : Files.File_Types.Classification;
      Options  : Files.Types.Listing_Options)
      return Directory_Load_Result;

   --  Whether any image in Items still lacks the thumbnail a listing makes.
   --
   --  @param Items Loaded items.
   --  @return True when a background listing would add thumbnails.
   function Thumbnails_Missing (Items : Item_Vectors.Vector) return Boolean;

   type Item_Load_Result is record
      Success   : Boolean := False;
      Item      : Directory_Item;
      Error_Key : UString;
   end record;

   --  Stat a single path and build its directory item, classifying kind,
   --  filetype, icon, and metadata the same way directory loading does. Used to
   --  materialize a synthetic listing (such as the recent-items view) from a set
   --  of stored paths.
   --
   --  @param Full_Path Absolute or relative path to describe.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @return Loaded item, or a failure result when the path is missing or
   --  cannot be described.
   function Load_Item
     (Full_Path : String;
      Classes   : Files.File_Types.Classification)
      return Item_Load_Result;

   --  Compute the extra info for an item: a folder's child count, a
   --  document's page/entry/line count, or a symlink's target. This opens the
   --  folder or reads the file, so it is computed lazily for the selected item
   --  (via the window model) rather than for every item on load.
   --
   --  @param Path Full path of the item.
   --  @param Kind Item kind.
   --  @param Filetype Detected filetype (MIME-style) of the item.
   --  @param Show_Hidden Whether a folder's count includes hidden entries,
   --    as the listing shows them only when Settings.Show_Hidden_Files is
   --    set; True counts every entry.
   --  @return The extra info, or No_Info when there is none for the item.
   function Extra_Info_Of
     (Path        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String;
      Show_Hidden : Boolean := True)
      return Files.Extra_Info.Info;

   --  How many matches either search returns; one more found makes the
   --  answer Truncated.
   Max_Search_Results : constant := 1_000;

   --  How deep either search walks below its root; a folder past it goes
   --  unsearched and makes the answer Truncated.
   Max_Search_Depth : constant := 64;

   --  Compute a shallow signature for polling-based directory change detection.
   --
   --  @param Path Directory to inspect.
   --  @return Directory existence, item count, and latest modification time.
   function Directory_State
     (Path : String)
      return Directory_Signature;

   --  Compare two polling signatures for a directory.
   --
   --  @param Before_State Previously captured directory state.
   --  @param Path Directory to inspect again.
   --  @return Change result with the new state.
   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result;

   --  Build an item value classified by Classes, as a listing would.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Classes Filetype and icon maps items are classified by
   --    (Files.Settings.Classification_Of the settings).
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Classes     : Files.File_Types.Classification)
      return Directory_Item;

   --  Which host's filesystem naming rules Valid_Leaf_Name enforces. Host_Rules
   --  follows the operating system this build runs on: a POSIX host allows any
   --  visible character except '/', while Windows additionally forbids
   --  \ : < > " | ? *, the reserved device names (CON, LPT1, ...) and a trailing
   --  dot. The explicit variants let the rules be checked independently of the
   --  host. Names that are merely confusing -- empty, "." / "..", control
   --  characters, invalid UTF-8, and all- or trailing-whitespace -- are rejected
   --  under every rule set.
   type Name_Rules is (Host_Rules, Posix_Rules, Windows_Rules);

   --  Return whether Name is a safe leaf filename for create or rename.
   --
   --  @param Name Candidate filename without parent path components.
   --  @param Rules Which host's naming rules to apply (the running host by
   --    default).
   --  @return True when Name can be used as a direct child filename.
   function Valid_Leaf_Name
     (Name  : String;
      Rules : Name_Rules := Host_Rules)
      return Boolean;

   --  As Valid_Leaf_Name, but choosing the rules from the filesystem that holds
   --  Directory -- the place the file is about to be created or renamed. A FAT,
   --  exFAT or NTFS destination is validated against Windows rules even on a
   --  POSIX host (a colon is fine on the ext4 disk but not on the FAT stick),
   --  and a POSIX destination against POSIX rules. Use this at create and rename
   --  sites; the plain Valid_Leaf_Name is for tests and callers without a
   --  destination in hand.
   --
   --  @param Name Candidate filename without parent path components.
   --  @param Directory The directory the name will live in.
   --  @return True when Name can be used as a direct child filename there.
   function Valid_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean;

   --  Return a deterministic available untitled file name in Directory_Path.
   --
   --  @param Directory_Path Directory to inspect.
   --  @return Available name such as untitled.txt or untitled 2.txt.
   function Next_Untitled_Name
     (Directory_Path : String)
      return String;

   --  Create an empty regular file without replacing an existing entry.
   --
   --  @param Path File path to create.
   --  @return Mutation result.
   function Create_Empty_File
     (Path : String)
      return Mutation_Result;

   --  Create a directory without replacing an existing entry.
   --
   --  @param Path Directory path to create.
   --  @return Mutation result.
   function Create_Directory
     (Path : String)
      return Mutation_Result;

   --  Rename a filesystem entry after caller-side validation.
   --
   --  @param From_Path Existing path.
   --  @param To_Path Destination path.
   --  @param Expected_Identity Optional history snapshot verified before and after quarantining the source.
   --  @return Mutation result.
   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Expected_Identity : String := "")
      return Mutation_Result;

   --  The error a rename reports when it left the entry at neither name.
   Rename_Stranded_Key : constant String := "error.rename.stranded";

   --  Why a rename failed, for a caller that acts on the reason and not only
   --  reports the result's key.
   type Rename_Failure is
     (Rename_Refused,         --  Any reason not named below.
      Rename_Source_Missing,  --  The entry to rename is gone.
      Rename_Name_Invalid,    --  The destination cannot store the new name.
      Rename_Stranded);       --  Left at neither name (Rename_Stranded_Key).

   --  As Rename_Item, also telling why it failed and where the entry was left
   --  when it is at neither name: a case-only rename goes through a scratch
   --  name beside the original, and when the second hop and the way back both
   --  fail the entry stays at that scratch name -- reported as
   --  Rename_Stranded_Key, whose message names Left_At.
   --
   --  @param From_Path Existing path.
   --  @param To_Path Destination path.
   --  @param Left_At The path the entry was left at for Rename_Stranded_Key;
   --    empty otherwise.
   --  @param Failure Why the rename failed; Rename_Refused when it succeeded.
   --  @param Expected_Identity Optional history snapshot verified before and after quarantining the source.
   --  @return Mutation result.
   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Left_At   : out UString;
      Failure   : out Rename_Failure;
      Expected_Identity : String := "")
      return Mutation_Result;

   --  Sum the sizes of every descendant regular file under a directory.
   --
   --  The walk skips symbolic links (it never descends through a symlinked
   --  directory, which guards against link cycles) and stops early against two
   --  defensive caps: at most Max_Entries visited entries and Max_Depth levels
   --  of nesting. When a cap trips the result's Capped flag is set and the
   --  totals become a lower bound. Unreadable subdirectories are skipped rather
   --  than aborting the whole walk.
   --
   --  @param Path Directory whose contents are summed.
   --  @param Max_Entries Maximum number of entries to visit before capping.
   --  @param Max_Depth Maximum directory nesting depth to descend.
   --  @return Recursive size totals; Available is False when Path is unusable.
   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result;

   --  Create a symbolic link at Link_Path that refers to Source_Path.
   --
   --  Link_Path must not already exist and its parent directory must exist.
   --  The link stores Source_Path verbatim as its target. Used by the
   --  create-symlink command.
   --
   --  @param Source_Path Existing item the link should point at.
   --  @param Link_Path New symbolic link path to create.
   --  @return Mutation result with a localized error key on failure.
   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result;

   --  Create a hard link at Link_Path that shares Source_Path's inode.
   --
   --  Source_Path must name an existing file, Link_Path must not already exist,
   --  and its parent directory must exist. Used by the create-hard-link command.
   --
   --  @param Source_Path Existing file the link should share an inode with.
   --  @param Link_Path New hard link path to create.
   --  @return Mutation result with a localized error key on failure.
   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result;

   --  Permanently remove a file or empty directory.
   --
   --  The operation is explicit and never used by normal trash/delete commands.
   --
   --  @param Path Entry to permanently remove.
   --  @return Mutation result with a localized error key on failure.
   function Delete_Permanently
     (Path : String)
      return Mutation_Result;

   --  Quarantine a created entry and verify its recorded identity before deleting.
   --  A replacement is restored without deleting its contents.
   --  @param Path Created entry to remove.
   --  @param Expected_Identity Identity recorded when the entry was created.
   --  @param Expected_Tree_Revision Directory or regular-file revision recorded at publication.
   --  @return Success only when the verified entry was removed.
   function Delete_Created_Entry
     (Path : String; Expected_Identity, Expected_Tree_Revision : String) return Mutation_Result;

   --  Quarantine and remove a private staging tree by the identity captured
   --  when its root was created. Contents may legitimately change while work
   --  is in progress, so only the root identity is compared. A replacement is
   --  restored without deleting its contents.
   --  @param Path Private staging directory to remove.
   --  @param Expected_Identity Root identity captured at stage creation.
   --  @return Success only when the verified stage was removed.
   function Delete_Staging_Entry
     (Path : String; Expected_Identity : String) return Mutation_Result;

   --  Remove a helper transport (Files.Jobs.Transports) by the identity
   --  captured when it was created: no quarantine, recovery record or flush.
   --  A transport is an owner-only folder of protocol files under the user's
   --  temporary directory, holding no user data, and the removal never
   --  follows a link and takes its marker and lease last: one cut short
   --  leaves a transport the scavenger still recognizes and finishes. A
   --  folder that is not the one created (another identity) is left alone.
   --  @param Path Transport directory to remove.
   --  @param Expected_Identity Identity captured when the transport was created.
   --  @return Success only when the transport is gone.
   function Delete_Transport_Entry
     (Path : String; Expected_Identity : String) return Mutation_Result;

   --  @param Path Existing entry to inspect without following symbolic links.
   --  @return SHA-256 of a directory's recursive metadata and file contents,
   --    a regular-file metadata and content revision, or empty for a link or
   --    unverifiable entry.
   function Tree_Revision (Path : String) return String;

   --  Whether the entry at Path (a link included) still is the one whose
   --  identity token was recorded as Expected. The guard Undo and Redo use
   --  before touching anything they once created or moved.
   --  @param Path Entry to check.
   --  @param Expected Identity token recorded earlier; empty never matches.
   --  @return True when Path exists and has that identity.
   function Entry_Identity_Matches (Path, Expected : String) return Boolean;

   --  Whether the entry at Path is still exactly what an operation created:
   --  the same identity and, for anything but a link, the same tree revision.
   --  Undo deletes a created entry only when this holds.
   --  @param Path Created entry to check.
   --  @param Identity Identity token recorded when it was created.
   --  @param Tree_Revision Tree revision recorded then; empty for a link.
   --  @param Retain_Verified Accept an entry already verified once whose
   --    identity has since changed (a later pathname replacement).
   --  @return True when Path is still the created entry.
   function Creation_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean;

   --  Optional cooperative cancellation, checked between copy chunks and entries.
   type Cancellation_Check is access function return Boolean;

   --  The error key of a drop or paste that stopped because it was cancelled,
   --  and only then: a failure that merely coincides with a cancel (a
   --  destination that appeared, a full disk) keeps its own key.
   Cancelled_Error_Key : constant String := "error.drop.cancelled";

   --  The result a transfer helper leaves while an import is under way: read
   --  back only when the helper ended before writing the real one -- killed
   --  after a cancel it ignored, or dead on its own.
   Interrupted_Error_Key : constant String := "error.drop.interrupted";

   --  Where a drop's or paste's failure key is read (Says_Only_Stopped):
   --  * Copy_Step: as a copy or move step leaves it, where a stop raised
   --    part way through reads as the generic "error.drop.failed";
   --  * Finished_Job: as a finished transfer job reports it, where every
   --    such stop already carries Cancelled_Error_Key (Execute_Drop_Import
   --    gives it), so "error.drop.failed" there is a failure of its own (a
   --    destination that appeared).
   type Failure_Reading is (Copy_Step, Finished_Job);

   --  The one rule for telling a cancel from a failure of its own: whether a
   --  failure key says no more than that the work stopped -- no key, a
   --  cancel, an interruption, or, read at a Copy_Step, the generic
   --  "error.drop.failed". A cancelled job's failure with such a key is
   --  reported as the cancel; any other key (a full disk, a collision) has
   --  a cause of its own and is reported as such.
   --  @param Error_Key The failure's message key.
   --  @param Reading Where the key is read.
   --  @return True when the key names no cause beyond the stop.
   function Says_Only_Stopped (Error_Key : String; Reading : Failure_Reading) return Boolean is
     (Error_Key in "" | Cancelled_Error_Key | Interrupted_Error_Key
      or else (Reading = Copy_Step and then Error_Key = "error.drop.failed"));

   --  The job's own cancellation (Files.Jobs.Context.Cancelled): what a copy
   --  or a check stops for unless it is handed another check, or null for
   --  none -- recovery, which must finish once the job is cancelled.
   --  @return Files.Jobs.Context.Cancelled.
   function Job_Cancelled return Cancellation_Check;

   --  Read up to Max_Bytes leading bytes of a file as a raw String, for a
   --  bounded text preview. Returns an empty string when the file cannot be
   --  opened or read. Never blocks beyond the capped read.
   --
   --  @param Path File to read.
   --  @param Max_Bytes Maximum number of leading bytes to return.
   --  @return Leading bytes as a String, or an empty string on failure.
   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String;

   --  @param Path File to read.
   --  @param Max_Bytes Maximum number of leading bytes to return.
   --  @param Success False on an open or read failure, True for valid empty files.
   --  @return Leading bytes; ignore them when Success is False.
   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success : out Boolean) return String;

   --  @param Path File to read.
   --  @param Max_Bytes Maximum number of leading bytes to return.
   --  @param Success False on an open or read failure, True for valid empty files.
   --  @param Complete False when the file is longer than the bytes returned.
   --  @return Leading bytes; ignore them when Success is False.
   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success, Complete : out Boolean) return String;
private

   --  Whether an entry is hidden: a leading dot in its name, or the host's
   --  hidden flag (Hostkit.Fs.Is_Hidden: Windows' attribute, macOS's
   --  UF_HIDDEN). The one rule the listing, the tree, folder counts, Recent
   --  and made-up items share. A flag that cannot be read leaves the name
   --  to decide, so an entry is never dropped for it.
   --
   --  @param Name The entry's name.
   --  @param Full Its full path.
   --  @return True when it is hidden.
   function Entry_Is_Hidden (Name : String; Full : String) return Boolean;

   --  Whether Child is Parent or lies inside it, by Path_Is_Within's rule
   --  with Folds answering whether a volume folds names in place of
   --  Hostkit.Fs.Folds_Name_Case: the rule apart from the volumes there are,
   --  for the test suite (Files.File_System.Testing).
   --
   --  @param Child Candidate path.
   --  @param Parent Candidate ancestor.
   --  @param Folds Whether the volume holding a folder folds names.
   --  @return True when Child is Parent or lies inside it.
   function Path_Is_Within_By
     (Child, Parent : String;
      Folds         : not null access function (Directory : String) return Boolean)
      return Boolean;

   --  The one rule every "is this path inside that one" check here follows:
   --  Hostkit.Fs.Is_Same_Or_Inside on the text (a root such as "/" or "C:\"
   --  holds every longer path; /a/bc is not inside /a/b), and on the
   --  case-folded text too where each of Parent's names may be folded: a
   --  name compares by the rule of the folder it is in (Hostkit.Fs.
   --  Folds_Name_Case of that folder, or of a root itself), since where
   --  that folds C:\Data and c:\data are one folder. So the folders above
   --  a mount compare exactly and only from the mount point down are names
   --  folded: a case-folding stick mounted at /media/u/STICK does not make
   --  /media/u/stick the same folder, as /media/u, where both names are,
   --  tells them apart, nor /MEDIA/u/STICK, as / does. Below Parent the
   --  spelling does not matter: Child is inside once its head is Parent.
   --  The volume is asked only when the spellings differ by case alone, so
   --  an exact match never waits on a slow mount. Making the paths absolute
   --  or resolving links is the caller's choice.
   --  @param Child Candidate path.
   --  @param Parent Candidate ancestor.
   --  @return True when Child is Parent or lies inside it.
   function Path_Is_Within (Child, Parent : String) return Boolean;

   --  Rolling checksums (directory signatures, thumbnail cache names) all
   --  reduce by this prime, so each fits a Natural.
   Checksum_Modulus : constant := 1_000_000_007;

   --  Fold Value into the rolling checksum Sum: Sum * Step + Value, reduced
   --  by Checksum_Modulus. Step 1 adds Value to a sum of checksums.
   --
   --  @param Sum The checksum so far, below Checksum_Modulus.
   --  @param Value What to fold in, not negative.
   --  @param Step What each fold multiplies Sum by.
   --  @return The new checksum.
   function Mix_Checksum
     (Sum   : Natural;
      Value : Long_Long_Integer;
      Step  : Positive := 131)
      return Natural is
     (Natural
        ((Long_Long_Integer (Sum) * Long_Long_Integer (Step) + Value mod Checksum_Modulus) mod Checksum_Modulus));

   --  Whether Name, the name of a file that already exists, can be stored in
   --  Directory: only what that filesystem cannot hold is refused -- empty,
   --  "." / "..", a separator or NUL on POSIX; Windows rules on a FAT, exFAT or
   --  NTFS destination (which cannot store invalid UTF-8 either). A name
   --  another program created ("notes " with a trailing space, bytes that are
   --  not UTF-8) copies and moves like any other; Valid_Leaf_Name_At, for
   --  names a user types, refuses those too.
   --
   --  @param Name Existing filename without parent path components.
   --  @param Directory The directory the name will live in.
   --  @return True when the destination can hold Name.
   function Storable_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean;

   --  Read at most Max_Bytes of a regular file, never following a link and
   --  never blocking on a FIFO. Complete is False when the file is longer.
   --  The thumbnail writers (Files.File_System.Thumbnails) read sources so.
   function Read_Bounded_Regular_File
     (Path : String; Max_Bytes : Natural;
      Success, Complete : out Boolean) return String;

   --  What a copy calls with the path of each entry whose metadata it has
   --  just set, before it checks the source against the copy.
   type Copy_Hook is access procedure (Destination : String);

   --  Set only by the test suite (Files.File_System.Testing): it changes the
   --  source there, as an editor saving at that moment would, so that the
   --  check that refuses to remove a changed source is exercised on every
   --  host. The application never sets it.
   After_Metadata : Copy_Hook := null
     with Atomic;

   --  What a rename asks before it gives a read-only folder back the mode
   --  it lent it write access from (Hostkit.Directory_Write_Access).
   type Restore_Hook is access function (Directory : String) return Boolean;

   --  Set only by the test suite (Files.File_System.Testing): True for the
   --  folder now at Directory refuses the restoration, as a failing chmod
   --  would. The application never sets it.
   Refuse_Directory_Restore : Restore_Hook := null
     with Atomic;

   --  Set only by the test suite (Files.File_System.Testing): True for an
   --  entry at Path inside a folder of ours refuses its delete, as a Windows
   --  sharing violation would. The application never sets it.
   Refuse_Owned_Delete : Restore_Hook := null
     with Atomic;

   --  Set only by the test suite (Files.File_System.Testing): True for an
   --  entry at Path makes Creation_Matches refuse it, as an entry something
   --  else touched since its creation would be. The application never sets it.
   Refuse_Creation_Match : Restore_Hook := null
     with Atomic;

   --  What a recovery-registry sweep calls with each registered payload just
   --  before it works on it, after it has let the registry lock go.
   type Sweep_Hook is access procedure (Payload : String);

   --  Set only by the test suite (Files.File_System.Testing.Pause_Sweep_Work):
   --  it holds a sweep there, as a slow trash move would, so the suite can
   --  show the registry stays open to Register meanwhile. The application
   --  never sets it.
   During_Sweep_Work : Sweep_Hook := null
     with Atomic;

end Files.File_System;
