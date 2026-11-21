with Files.Jobs.Copy_Context;
with Files.Extra_Info;
with Ada.Calendar;
with Ada.Containers.Vectors;

with Files.Settings;
with Files.Items;
with Files.Types;
with Files.File_System_Types;

--  Filesystem inspection, directory loading, and mutation result modeling.
package Files.File_System is
   subtype UString is Files.Types.UString;

   --  The value types below live in Files.File_System_Types, so a unit
   --  that only holds them need not depend on this package; they are
   --  re-exported here under their own names, literals included. Their
   --  operators are not this package's own, so they are made visible to it
   --  and its children here.
   use type Files.File_System_Types.Drop_Import_Mode;
   use type Files.File_System_Types.Root_Kind;

   subtype Path_Status is Files.File_System_Types.Path_Status;
   --  @return The literal Path_Valid of Path_Status, as Files.File_System_Types names it.
   function Path_Valid return Path_Status renames Files.File_System_Types.Path_Valid;
   --  @return The literal Path_Missing of Path_Status, as Files.File_System_Types names it.
   function Path_Missing return Path_Status renames Files.File_System_Types.Path_Missing;
   --  @return The literal Path_Inaccessible of Path_Status, as Files.File_System_Types names it.
   function Path_Inaccessible return Path_Status renames Files.File_System_Types.Path_Inaccessible;

   subtype Path_Result is Files.File_System_Types.Path_Result;

   --  The item type is Files.Items'; these names keep it at hand here.
   subtype Directory_Item is Files.Items.Directory_Item;
   package Item_Vectors renames Files.Items.Item_Vectors;

   subtype Directory_Signature is Files.File_System_Types.Directory_Signature;

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

   --  A search's answer. Success with Items is an answer to show, partial
   --  or not; only a root that could not be searched at all fails.
   type Recursive_Search_Result is record
      Success   : Boolean := False;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
      --  A limit stopped the walk before it saw everything (the match cap,
      --  Max_Search_Depth, the scan caps): Items are the first found.
      Truncated : Boolean := False;
      --  Something under the root could not be searched (a folder or file
      --  that could not be read, a text file longer than is read with no
      --  match in what was): a match there is missing from Items.
      Incomplete : Boolean := False;
   end record;

   type Directory_Change_Result is record
      Changed        : Boolean := False;
      Before_State   : Directory_Signature;
      After_State    : Directory_Signature;
      Error_Key      : UString;
   end record;

   subtype Drop_Import_Mode is Files.File_System_Types.Drop_Import_Mode;
   --  @return The literal Drop_Copy of Drop_Import_Mode, as Files.File_System_Types names it.
   function Drop_Copy return Drop_Import_Mode renames Files.File_System_Types.Drop_Copy;
   --  @return The literal Drop_Move of Drop_Import_Mode, as Files.File_System_Types names it.
   function Drop_Move return Drop_Import_Mode renames Files.File_System_Types.Drop_Move;

   type Drop_Import_Plan is record
      Source_Path      : UString;
      Destination_Path : UString;
      Mode             : Drop_Import_Mode := Drop_Copy;
      Valid            : Boolean := False;
      Error_Key        : UString;
   end record;

   package Drop_Import_Plan_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Drop_Import_Plan);

   type Drop_Import_Result is record
      Success   : Boolean := False;
      Plans     : Drop_Import_Plan_Vectors.Vector;
      Error_Key : UString;
   end record;

   type Mutation_Result is record
      Success   : Boolean := False;
      Error_Key : UString;
   end record;

   subtype Directory_Size_Result is Files.File_System_Types.Directory_Size_Result;

   type Trash_Backend is
     (Trash_Unavailable,
      Trash_Windows_Recycle_Bin,
      Trash_Macos_Native,
      Trash_Xdg_Data_Home,
      Trash_Home_Data,
      Trash_Macos_Home);

   type Native_Trash_Request is record
      Backend                 : Trash_Backend := Trash_Unavailable;
      Path                    : UString;
      Requires_Native_Api     : Boolean := False;
      Can_Use_Current_Process : Boolean := False;
   end record;

   --  What became of a request for the trash. Supported: this host has that
   --  trash here. Attempted: the move was tried (False when unsupported, so a
   --  refusal is told apart from an absent trash). Error_Key: why it did not
   --  complete.
   type Native_Trash_Result is record
      Supported : Boolean := False;
      Attempted : Boolean := False;
      Completed : Boolean := False;
      Error_Key : UString;
   end record;

   subtype Root_Kind is Files.File_System_Types.Root_Kind;
   --  @return The literal Root_Filesystem of Root_Kind, as Files.File_System_Types names it.
   function Root_Filesystem return Root_Kind renames Files.File_System_Types.Root_Filesystem;
   --  @return The literal Root_Home of Root_Kind, as Files.File_System_Types names it.
   function Root_Home return Root_Kind renames Files.File_System_Types.Root_Home;
   --  @return The literal Root_Current of Root_Kind, as Files.File_System_Types names it.
   function Root_Current return Root_Kind renames Files.File_System_Types.Root_Current;
   --  @return The literal Root_Mount of Root_Kind, as Files.File_System_Types names it.
   function Root_Mount return Root_Kind renames Files.File_System_Types.Root_Mount;
   --  @return The literal Root_User_Mount of Root_Kind, as Files.File_System_Types names it.
   function Root_User_Mount return Root_Kind renames Files.File_System_Types.Root_User_Mount;
   --  @return The literal Root_Network_Mount of Root_Kind, as Files.File_System_Types names it.
   function Root_Network_Mount return Root_Kind renames Files.File_System_Types.Root_Network_Mount;
   --  @return The literal Root_Windows_Drive of Root_Kind, as Files.File_System_Types names it.
   function Root_Windows_Drive return Root_Kind renames Files.File_System_Types.Root_Windows_Drive;
   --  @return The literal Root_Favorite of Root_Kind, as Files.File_System_Types names it.
   function Root_Favorite return Root_Kind renames Files.File_System_Types.Root_Favorite;

   subtype Root_Entry is Files.File_System_Types.Root_Entry;
   package Root_Entry_Vectors renames Files.File_System_Types.Root_Entry_Vectors;

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
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

   --  Load_Directory that also decodes each image lacking a cached thumbnail
   --  and writes its cache file. Slow on a folder of new photos, so it is for
   --  the background listing (Files.Refresh), not a read the UI waits on.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory_Generating_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

   --  Load only the entries Include accepts (null accepts all); the others
   --  are skipped after a cheap kind check, so a caller that wants one kind,
   --  such as the folder tree's subdirectories, does not stat, classify and
   --  thumbnail every file it passes.
   --
   --  This is the one load that applies the listing policy; it takes it as
   --  Options rather than reading it from Settings, which it consults only for
   --  filetype and icon classification. The Settings-only loads above and
   --  below pass Files.Settings.Listing_Options_Of (Settings).
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings used for filetype and icon classification.
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
      Settings : Files.Settings.Settings_Model;
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
   --  @param Settings Settings model used for filtering and item metadata.
   --  @return Directory load result.
   function Load_Directory_Deferring_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

   --  Path's subdirectories, for the folder tree: named, dated and classified
   --  for the listing's sort, in its order, but without the per-item
   --  metadata, thumbnails and file kinds a listing builds. Expanding a node
   --  over a large folder took a full listing's time (200 ms for 22,000
   --  entries) on the UI thread; this takes one no-follow stat per entry
   --  where mode bits are native. A link to a folder is not a subdirectory.
   --
   --  @param Path Directory whose subdirectories are listed.
   --  @param Settings Settings used for filetype and icon classification.
   --  @param Options Hidden-entry and sort policy.
   --  @return The subdirectories, or a recoverable error result.
   function Load_Subdirectories
     (Path     : String;
      Settings : Files.Settings.Settings_Model;
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
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded item, or a failure result when the path is missing or
   --  cannot be described.
   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result;

   --  The Recent view's items: each recorded recent path loaded (Load_Item)
   --  in most-recent-first order, one that no longer resolves left out. The
   --  one way the view is built, whether navigated to, refreshed after a
   --  change, or reloaded by a background refresh.
   --
   --  @param Settings Settings holding the recent paths and used to classify.
   --  @return The loaded items.
   function Load_Recent_Items (Settings : Files.Settings.Settings_Model) return Item_Vectors.Vector;

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

   --  Sort Items in place into the display order for the given sort field and
   --  direction (Files.Item_Lists.Sort_Items). Shared by directory loading and by the window model so that
   --  keyboard navigation follows exactly the order shown on screen, in either
   --  sort direction.
   --
   --  @param Items Item vector reordered in place.
   --  @param Field Sort field to order by.
   --  @param Ascending Ascending order when True, descending when False.
   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean);

   --  How many matches either search returns; one more found makes the
   --  answer Truncated.
   Max_Search_Results : constant := 1_000;

   --  How deep either search walks below its root; a folder past it goes
   --  unsearched and makes the answer Truncated.
   Max_Search_Depth : constant := 64;

   --  Search a directory tree recursively for item names matching Query.
   --  A folder below the root that cannot be read is skipped (Incomplete),
   --  and a limit reached ends the walk (Truncated); both keep what was found.
   --
   --  @param Root_Path Directory where recursive search starts.
   --  @param Query Case-insensitive name fragment to match.
   --  @param Settings Settings used for filetype, icon, and hidden-file policy.
   --  @param Max_Items Maximum number of matching items to return.
   --  @return Deterministic recursive search result or recoverable error.
   function Search_Names
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := Max_Search_Results)
      return Recursive_Search_Result;

   --  Whether Bytes, text and not binary, contain Query, ignoring case.
   --  UTF-16 and Windows-1252 text is searched as what it says
   --  (Files.Text_Encoding.Searchable_Text).
   --
   --  @param Bytes A file's first bytes.
   --  @param Query Text to look for; "" matches nothing.
   --  @return True for a text match.
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean;

   --  Search a directory tree for text files whose first 64 KiB contain
   --  Query, ignoring case, with Search_Names's walk: real folders only
   --  (a linked folder is an item, so cycles are impossible), Max_Search_Depth
   --  deep, and cancellable. Past its limits (Max_Search_Results matches,
   --  20,000 files read) the answer is Truncated; a file it could not read,
   --  or a text file larger than it reads with no match in what it read,
   --  makes it Incomplete.
   --
   --  @param Root_Path Directory where the search starts.
   --  @param Query Text to look for.
   --  @param Settings Settings used for filetype, icon, and hidden-file policy.
   --  @return The matching files, or why the search failed.
   function Search_Contents
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model)
      return Recursive_Search_Result;

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

   --  Return available filesystem root locations with labels and source kind.
   --
   --  @return Root entries available on the host platform.
   function Available_Root_Entries return Root_Entry_Vectors.Vector;

   --  Return the label of a root location: a localization key (e.g.
   --  "root.home", or "root.mount", whose pattern takes Root_Name as {name}),
   --  or, for a plain filesystem root, its path.
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return Label key or literal text.
   function Root_Label (Path : String; Kind : Root_Kind) return String;

   --  Return the {name} a root's label pattern takes: a mount's or a
   --  favorite's leaf name, a drive's path; empty for kinds with no name.
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return The name, which may hold any character a file name can.
   function Root_Name (Path : String; Kind : Root_Kind) return String;

   --  Build an item value for tests and pure model setup, reading no disk
   --  (Files.Item_Lists.Make_Item): hidden when its name starts with a dot.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Filetype Filetype identifier.
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item;

   --  Build an item value using settings-driven filetype and icon classification.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Item name.
   --  @param Kind Filesystem item kind.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Directory item value.
   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
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

   --  Return whether Path is an application-owned replacement recovery payload.
   --  @param Path Possible recovery payload path.
   --  @return True only for a recognized application recovery payload.
   function Is_Recovery_Payload (Path : String) return Boolean;

   --  Move a recovery payload nothing will restore any more -- its undo
   --  history is ending with the window -- to the system trash under its
   --  original name, and remove the hidden folder that held it.
   --  @param Path Recognized application recovery payload.
   --  @return Success when the payload is in the trash.
   function Release_Recovery_Payload (Path : String) return Mutation_Result;

   --  Return recoverable replacement payloads recorded across directories.
   --  Stale or damaged registry entries are omitted. A pure query: it
   --  changes nothing on disk (see Sweep_Recovery_Registry).
   --  @return Valid registered replacement-recovery payload paths.
   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector;

   --  Finish interrupted recovery work the registry records: drop stale and
   --  duplicate records, resume a stopped release, and remove a stage whose
   --  payload a restore or release moved out on purpose. A stage another
   --  operation is still filling is left alone, so this is safe to run while
   --  other processes preserve, restore or release.
   procedure Sweep_Recovery_Registry;

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

   --  Recursively copy a file or directory tree to a new destination path.
   --
   --  The destination must not already exist. Directories are copied with their
   --  full contents. Used by the duplicate command.
   --
   --  @param Source_Path Existing file or directory to copy.
   --  @param Destination_Path New path to create.
   --  @param Batch Shared hard-link journal for consecutive copies.
   --  @return Mutation result with a localized error key on failure.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Copy while returning snapshots captured before atomic publication.
   --  @param Source_Path Existing file or directory to copy.
   --  @param Destination_Path New path to create.
   --  @param Identity Published entry identity.
   --  @param Tree_Revision_Value Directory or regular-file revision, empty for links.
   --  @param Batch Shared hard-link journal for consecutive copies.
   --  @return Mutation result with a localized error key on failure.
   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Put a staged file or folder at Target, never over an entry already
   --  there: its identity and tree revision taken first, the whole of it
   --  flushed to the device (a power cut leaves no recorded but empty or cut
   --  short output), named as intended (Files.Jobs.Context.Intend_Created),
   --  renamed into place, given the access its new folder hands down (as a
   --  published copy is, its revision read again where that changed it and
   --  named again with it), recorded as created, and its new name flushed --
   --  the publication Copy_Tree's copies share (Support.Publish_From_Stage). A failure of that last
   --  flush is traced, not returned: the entry is published and recorded,
   --  as a Durable_Writes publication that is Published_Not_Durable. The one
   --  way Compress and Extract publish what they made.
   --
   --  @param Staged The finished file or folder inside a stage.
   --  @param Target Where it is published.
   --  @param Identity Set to its identity token, for its Undo.
   --  @param Revision Set to its tree revision, for its Undo.
   --  @return False when it was not published; Staged is then left for the
   --    caller to discard with its stage.
   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out UString;
      Revision : out UString)
      return Boolean;

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

   --  Preserve an overwritten destination in a location this application can restore.
   --  Native trash backends use an adjacent recovery backup instead of the OS bin.
   --  @param Path Destination to preserve before replacement.
   --  @param Recovery_Path Payload for rollback and Undo.
   --  @return Result of preserving the destination.
   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result;

   --  Build deterministic copy/move plans for paths dropped into a directory.
   --
   --  @param Source_Paths Paths received from a drag-and-drop operation.
   --  @param Destination_Directory Directory receiving the dropped entries.
   --  @param Mode Copy or move mode for all valid plans.
   --  @return Planned destination paths and validation diagnostics.
   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result;

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

   --  Import one paste action, preserving the destination it replaces first
   --  and putting that original back when the import fails. The one routine
   --  behind both the in-process paste and the transfer helper: a replace
   --  target that vanished after planning has nothing to preserve and the
   --  import proceeds; a destination that is the source itself is never
   --  preserved, so a same-path move is a no-op success (and a same-path
   --  copy fails as Execute_Drop_Import fails it).
   --  @param Source Entry to copy or move.
   --  @param Destination New pathname.
   --  @param Mode Copy or move.
   --  @param Replace Whether an existing Destination is to be replaced.
   --  @param Replaced Where the replaced original is held, or empty: empty
   --    when nothing was preserved or the original was put back.
   --  @param Replaced_Identity Identity of Replaced, or empty.
   --  @param Created_Identity Identity of the published destination.
   --  @param Created_Tree_Revision Tree revision of the published destination.
   --  @param Preserved Called once the original is held at Backup (with its
   --    identity), before the import starts -- also when preserving failed
   --    yet left the original there; an exception from it fails the action
   --    and the original is put back.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal.
   --  @return Success when Destination holds the imported entry; otherwise
   --    the preserving, import, or restoring failure. A cross-device move
   --    that failed yet had to keep its copy at Destination (see
   --    Execute_Drop_Import) also fails, with Created_Identity set to that
   --    copy and the original left held at Replaced: Destination is taken,
   --    so the original is not put back, and the caller records both.
   function Import_Replacing
     (Source, Destination   : String;
      Mode                  : Drop_Import_Mode;
      Replace               : Boolean;
      Replaced              : out Files.Types.UString;
      Replaced_Identity     : out Files.Types.UString;
      Created_Identity      : out Files.Types.UString;
      Created_Tree_Revision : out Files.Types.UString;
      Preserved             : access procedure (Backup, Backup_Identity : String) := null;
      Cancel                : Cancellation_Check := Job_Cancelled;
      Batch                 : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Put an original that a failed replace preserved back at Destination:
   --  the one rollback behind Import_Replacing and the transfer helper. With
   --  nothing held (Replaced empty) it does nothing.
   --  @param Replaced Where the original is held; emptied once it is back.
   --  @param Replaced_Identity Identity of Replaced; emptied with it.
   --  @param Destination Where the original came from.
   --  @param Result The action's result, replaced by the restore's failure
   --    when the original cannot be put back.
   procedure Put_Back_Replaced
     (Replaced, Replaced_Identity : in out Files.Types.UString;
      Destination                 : String;
      Result                      : in out Mutation_Result);

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

   --  Declared for Permissions (renamed there) and for the parent's own
   --  bodies and private children, which keep calling them by these names.

   --  Return whether this build can read and change POSIX permission bits.
   --
   --  @return True on the Linux platform, False on the stub platforms.
   function Supports_Permissions return Boolean;

   --  Return the POSIX permission bits of Path (the low 12 mode bits).
   --
   --  @param Path Existing filesystem path to inspect.
   --  @param Available Set True when the permission bits were obtained.
   --  @return Permission bits in 0 .. 8#7777#, or 0 when Available is False.
   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural;

   --  Change the POSIX permission bits of an existing entry through chmod(2).
   --
   --  The path must already exist. Mode carries the numeric POSIX permission
   --  bits (the low 12 bits). Failures map to error.permissions.failed, and an
   --  unsupported platform maps to error.permissions.unsupported.
   --
   --  Exact, not an edit: on Windows the entry's access becomes just the
   --  three accounts' bits (Hostkit.Metadata.Set_Exact_Permissions), so 0
   --  takes access away even from an administrator -- what a test's fixture
   --  needs. A user's edit goes through Change_Access, which changes only
   --  what the bits do.
   --
   --  @param Path Existing filesystem path whose mode is changed.
   --  @param Mode New permission bits to apply.
   --  @return Mutation result with a localized error key on failure.
   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result;

   --  Return whether this build can read and change file ownership.
   --
   --  @return True on the Linux platform, False on the stub platforms.
   function Supports_Ownership return Boolean;

   --  Change the permission bits of one verified entry as a user's edit does, reporting its whole
   --  access record too where the mode cannot hold it all: on Windows the
   --  DACL, before and after (Hostkit.Metadata.Update_Entry_Metadata), which
   --  the edit changes only where the bits do. With Access_Text -- a record
   --  reported earlier -- that record is put back exactly instead of Mode:
   --  how an undo restores the access an edit changed. The records are empty
   --  on a POSIX host, where the mode is the whole of it and Access_Text is
   --  ignored.
   --
   --  @param Path Existing entry; symbolic links must be resolved by the caller.
   --  @param Expected_Identity History identity to verify, or empty for a new live change.
   --  @param Mode New permission bits, 0 .. 8#7777#.
   --  @param Access_Text An access record to restore instead of Mode, or "".
   --  @param Previous Live previous permission bits captured before mutation.
   --  @param Previous_Access The access record before the change, or "".
   --  @param Applied_Access The access record after it, or "".
   --  @param Identity Identity of the entry actually changed.
   --  @return Result of applying the change to the verified entry.
   function Change_Access
     (Path, Expected_Identity : String; Mode : Natural; Access_Text : String;
      Previous : out Natural; Previous_Access, Applied_Access, Identity : out Files.Types.UString)
      return Mutation_Result;

   --  Change the owner and group of one verified entry through a handle that
   --  pins it, capturing the ids it had.
   --
   --  @param Path Existing entry; symbolic links must be resolved by the caller.
   --  @param Expected_Identity History identity to verify, or empty for a new live change.
   --  @param User_Id New owning user id.
   --  @param Group_Id New owning group id.
   --  @param Previous_User Live previous user id captured before mutation.
   --  @param Previous_Group Live previous group id captured before mutation.
   --  @param Identity Identity of the entry actually changed.
   --  @param Owner_Name Native account name paired with User_Id when required.
   --  @param Group_Name Native account name paired with Group_Id when required.
   --  @return Result of applying the ownership to the verified entry.
   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result;

   --  Resolve a user name to its numeric id (getpwnam).
   --
   --  @param Name User name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The user id when Found, otherwise 0.
   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id;

   --  Resolve a group name to its numeric id (getgrnam).
   --
   --  @param Name Group name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The group id when Found, otherwise 0.
   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id;

   --  Resolve a numeric user id to its name (getpwuid), memoized for the session.
   --
   --  @param Id User id to resolve.
   --  @return The user name, or the empty string when it cannot be resolved.
   function User_Name_For_Id (Id : Files.Types.Account_Id) return String;

   --  Resolve a numeric group id to its name (getgrgid), memoized for the session.
   --
   --  @param Id Group id to resolve.
   --  @return The group name, or the empty string when it cannot be resolved.
   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String;

   --  Declared for Trash (renamed there) and for the parent's own
   --  bodies and private children, which keep calling them by these names.

   --  Return whether a platform trash backend is available in the current environment.
   --
   --  @return True when Move_To_Trash can use a configured trash location.
   function Trash_Is_Available return Boolean;

   --  Validate whether an entry can be moved to the selected trash backend.
   --
   --  This performs non-mutating checks used before multi-item delete so later
   --  failures do not move earlier selected files.
   --
   --  @param Path Entry to preflight for trash movement.
   --  @return Success when Move_To_Trash can be attempted safely.
   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result;

   --  Return the directory that holds trashed payloads for the current backend.
   --
   --  This is <Trash_Base_Path>/files for the freedesktop XDG and home-data
   --  backends, and <Trash_Base_Path> itself for the macOS flat home backend.
   --
   --  @return Trashed-payload directory, or an empty string when unavailable.
   function Trash_Files_Directory return String;

   --  Remove the freedesktop trashes' info files (home and volume) whose
   --  item is surely not there and that are older than a trash in progress
   --  can be: a trash writes its info file before the item moves in, so a
   --  crash between the two (or a move lost before the folder was synced)
   --  leaves one describing nothing, which keeps its name taken.
   procedure Remove_Orphan_Trash_Info;

   --  Return whether Path identifies the active trash payload directory.
   --  Filesystem identity is used when possible so aliases such as symbolic
   --  links cannot bypass trash-view safety rules.
   --
   --  @param Path Existing directory path to compare with the trash payload.
   --  @return True only when Path identifies the active payload directory.
   function Is_Trash_Files_Directory (Path : String) return Boolean;

   --  Whether Path is an item in a volume's own trash, which the trash view
   --  lists beside the home trash's items.
   --
   --  @param Path Entry to test.
   --  @return True when Path is directly in a valid volume trash's files/.
   function Is_Volume_Trash_Item (Path : String) return Boolean;

   --  Capture a payload's original path before recording restore history.
   --  @param Trashed_Path Trash or replacement recovery payload pathname.
   --  @return Original path from its sidecar, or empty on failure.
   function Trash_Original_Path (Trashed_Path : String) return String;

   --  Restore a trashed payload to its recorded original location.
   --
   --  For freedesktop backends the original path is read from the matching
   --  <base>/info/<name>.trashinfo sidecar, URL-decoded, and the payload is
   --  moved back; the sidecar is removed on success. Backends without a sidecar
   --  fail with error.trash.restore_unavailable.
   --
   --  @param Trashed_Path Payload path inside the trash files directory.
   --  @param Expected_Identity Optional history snapshot verified before restoring the payload.
   --  @param Expected_Original Authoritative restore destination captured in history.
   --  @return Mutation result with a localized error key on failure.
   function Restore_From_Trash
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result;

   --  Move an entry to trash when a supported trash backend is available.
   --
   --  @param Path Entry to move to trash.
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path : String)
      return Mutation_Result;

   --  As Move_To_Trash, but also report the payload's path inside the trash so
   --  callers can later restore it (used by Undo).
   --
   --  @param Path Entry to move to trash.
   --  @param Trashed_Path Set to the payload's location in the trash on success.
   --  @param Recorded_Path Where the trash says the item came from, so a
   --    restore puts it back there; empty means Path. A recovery payload
   --    names its original location this way, not its hidden stage.
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path          : String;
      Trashed_Path  : out Files.Types.UString;
      Recorded_Path : String := "")
      return Mutation_Result;

   --  Permanently delete a single trashed or application recovery payload and
   --  its metadata.
   --
   --  Removes the payload through Delete_Permanently and, for freedesktop
   --  backends, best-effort removes the matching <base>/info/<name>.trashinfo
   --  sidecar so the trash entry leaves no orphaned metadata behind. Sidecar
   --  removal never fails the operation; the payload deletion result is
   --  returned.
   --
   --  @param Trashed_Path Payload path inside the trash files directory.
   --  @return Mutation result with a localized error key on failure.
   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result;

   --  What one completed import plan published: the entry's identity token
   --  and, for a directory, its recursive tree revision.
   type Created_Entry is record
      Identity      : Files.Types.UString;
      Tree_Revision : Files.Types.UString;
   end record;

   package Created_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Created_Entry);

   --  Execute validated drag-and-drop import plans, returning what each
   --  completed plan published, in plan order. A cross-device move whose
   --  copy had to stay at its destination (its source was set aside in
   --  recovery, or the copy could not be removed) fails, yet its copy is
   --  appended too: it is the plan's result for undo. Import_Replacing runs
   --  one plan through it; the suite drives several through
   --  Files.File_System.Testing.Execute_Drop_Import.
   --
   --  @param Plans Plans produced by Plan_Drop_Import.
   --  @param Created What each completed plan published.
   --  @param Cancel What stops it: the job's cancellation unless given another, null for none.
   --  @param Batch Shared hard-link journal, created automatically for multiple plans.
   --  @return Mutation result with a localized error key on failure.
   function Execute_Drop_Import
     (Plans   : Drop_Import_Plan_Vectors.Vector;
      Created : out Created_Entry_Vectors.Vector;
      Cancel  : Cancellation_Check := Job_Cancelled;
      Batch   : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
      return Mutation_Result;

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

   --  Change the permission bits of one verified entry through a handle that
   --  pins it, capturing the bits it had. In the private part: only
   --  recovery, replaying a journalled change, sets bare bits; an edit goes
   --  through Change_Access.
   --
   --  @param Path Existing entry; symbolic links must be resolved by the caller.
   --  @param Expected_Identity History identity to verify, or empty for a new live change.
   --  @param Mode New permission bits, 0 .. 8#7777#.
   --  @param Previous Live previous permission bits captured before mutation.
   --  @param Identity Identity of the entry actually changed.
   --  @return Result of applying the mode to the verified entry.
   function Change_Mode
     (Path, Expected_Identity : String; Mode : Natural;
      Previous : out Natural; Identity : out Files.Types.UString) return Mutation_Result;

   --  Whether a mount point is one a user put there (a stick, a share), as
   --  the root list shows them: "/" and anything under /mnt, /media,
   --  /run/media, /Volumes, /System/Volumes or the session's gvfs directory,
   --  but not those containers themselves.
   --
   --  @param Mount_Point Absolute mount point.
   --  @param Runtime_Gvfs The session's gvfs directory, or "" when none.
   --  @return True when the mount is listed as a root.
   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean;

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

   --  Return the trash backend selected for the current environment.
   --
   --  @return Backend that Move_To_Trash will use, or Trash_Unavailable.
   function Trash_Backend_Of_Current_Environment return Trash_Backend;

   --  Evaluate native trash support for Request without deleting anything.
   --
   --  @param Request Native trash request metadata.
   --  @return Native trash support result.
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  Hand Request's item to the desktop's own trash (the Windows Recycle Bin
   --  or the macOS Trash). Nothing is attempted on a build that does not
   --  target that desktop.
   --
   --  @param Request Native trash request for a native backend.
   --  @return The evaluation, with Attempted and Completed set by the attempt.
   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     with Pre => Request.Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native;

   --  Format a timestamp for freedesktop trashinfo DeletionDate metadata.
   --
   --  @param Value Time value to format.
   --  @return Local timestamp in YYYY-MM-DDTHH:MM:SS form.
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String;

   --  Read at most Max_Bytes of a regular file, never following a link and
   --  never blocking on a FIFO. Complete is False when the file is longer.
   --  The thumbnail writers (Files.File_System.Thumbnails) read sources so.
   function Read_Bounded_Regular_File
     (Path : String; Max_Bytes : Natural;
      Success, Complete : out Boolean) return String;

   --  Set only by the test suite (Files.File_System.Testing.Refuse_Native_Trash):
   --  the desktop's own trash then refuses every item, as an unreachable
   --  Recycle Bin would, so the refusal paths can be exercised where the
   --  trash is reachable. The application never sets it.
   Native_Trash_Refused : Boolean := False
     with Atomic;

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

   --  What an ownership change calls with the path and the ids it asks
   --  for, before it asks the host.
   type Ownership_Hook is access procedure (Path : String; User_Id, Group_Id : Files.Types.Account_Id);

   --  Set only by the test suite (Files.File_System.Testing.Watch_Ownership_Changes):
   --  it counts the ownership changes asked for and keeps the last one's
   --  ids, so the suite can show which ones are asked for, and that none
   --  is for an edit that changes nothing. The application never sets it.
   Before_Ownership_Change : Ownership_Hook := null
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

   --  Set only by the test suite (Files.File_System.Testing.Replace_Trashed_After_Copy):
   --  called with the trashed item a restore from a trash on another device
   --  has just copied back, before it removes that item, so the suite can put
   --  another item under its name as emptying the trash and trashing again
   --  would. The application never sets it.
   After_Restore_Copy : Copy_Hook := null
     with Atomic;

end Files.File_System;
