with Files.Copy_Context;
with Files.Extra_Info;
with Ada.Calendar;
with Ada.Containers.Vectors;

with Files.Settings;
with Files.Fs_Primitives;
with Files.Items;
with Files.Types;

--  Filesystem inspection, directory loading, and mutation result modeling.
package Files.File_System is
   subtype UString is Files.Types.UString;

   type Path_Status is
     (Path_Valid,
      Path_Missing,
      Path_Inaccessible);

   type Path_Result is record
      Status         : Path_Status := Path_Missing;
      Directory_Path : UString;
      Error_Key      : UString;
   end record;

   --  The item type is Files.Items'; these names keep it at hand here.
   subtype Directory_Item is Files.Items.Directory_Item;
   package Item_Vectors renames Files.Items.Item_Vectors;

   type Directory_Signature is record
      Path               : UString;
      Exists             : Boolean := False;
      Entry_Count        : Natural := 0;
      Entry_State_Checksum : Natural := 0;
      Latest_Modified    : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Latest_Modified_Known : Boolean := False;
   end record;

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

   type Recursive_Search_Result is record
      Success   : Boolean := False;
      Root_Path : UString;
      Query     : UString;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
   end record;

   type Directory_Change_Result is record
      Changed        : Boolean := False;
      Before_State   : Directory_Signature;
      After_State    : Directory_Signature;
      Error_Key      : UString;
   end record;

   type Drop_Import_Mode is
     (Drop_Copy,
      Drop_Move);

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

   --  Recursive directory-size measurement. Total_Bytes sums the sizes of all
   --  descendant regular files; File_Count counts those files and Item_Count
   --  counts every visited entry (files plus directories). Capped is True when
   --  the walk stopped early against the entry-count or depth guard, so the
   --  totals are a lower bound. Available is False when the root was missing or
   --  unreadable.
   type Directory_Size_Result is record
      Available   : Boolean := False;
      Total_Bytes : Long_Long_Integer := 0;
      File_Count  : Natural := 0;
      Item_Count  : Natural := 0;
      Capped      : Boolean := False;
   end record;

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

   type Root_Readiness is
     (Root_Ready,
      Root_Missing,
      Root_Inaccessible);

   type Root_Kind is
     (Root_Filesystem,
      Root_Home,
      Root_Current,
      Root_Mount,
      Root_User_Mount,
      Root_Network_Mount,
      Root_Windows_Drive,
      Root_Favorite);

   type Root_Entry is record
      Path  : UString;
      --  A localization key ("root.home", "root.mount") or literal text.
      Label : UString;
      --  The {name} a key's pattern takes (a mount's leaf name), or empty.
      Name  : UString;
      --  A detail shown after the label (a mount's filesystem type), or empty.
      Detail : UString;
      Kind  : Root_Kind := Root_Filesystem;
      Volume_Name : UString;
      Ready       : Root_Readiness := Root_Ready;
      Removable   : Boolean := False;
   end record;

   package Root_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Entry);

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

   --  Return the parent directory of Path.
   --
   --  @param Path Directory path whose parent is requested.
   --  @return Parent directory path, or an empty string when Path is a
   --    filesystem root (or otherwise has no parent).
   function Parent_Directory
     (Path : String)
      return String renames Files.Fs_Primitives.Parent_Directory;

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
   --  the background listing (Files.Refresh_Jobs), not a read the UI waits on.
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
   --  direction. Shared by directory loading and by the window model so that
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

   --  Search a directory tree recursively for item names matching Query.
   --
   --  @param Root_Path Directory where recursive search starts.
   --  @param Query Case-insensitive name fragment to match.
   --  @param Settings Settings used for filetype, icon, and hidden-file policy.
   --  @param Max_Items Maximum number of matching items to return.
   --  @return Deterministic recursive search result or recoverable error.
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result;

   --  How deep either search walks below its root; a folder past it fails
   --  the search (error.search.failed) rather than silently go unsearched.
   Max_Search_Depth : constant := 64;

   --  Whether Bytes, text and not binary, contain Query, ignoring case.
   --
   --  @param Bytes A file's first bytes.
   --  @param Query Text to look for; "" matches nothing.
   --  @return True for a text match.
   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean;

   --  Search a directory tree for text files whose first 64 KiB contain
   --  Query, ignoring case, with Search_Recursive's walk: real folders only
   --  (a linked folder is an item, so cycles are impossible), Max_Search_Depth
   --  deep, cancellable, and failing rather than returning a partial answer
   --  past its limits (1,000 matches, 20,000 files read, a text file larger
   --  than it reads).
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

   --  Build an item value for tests and pure model setup.
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
   --  Stale or damaged registry entries are omitted.
   --  @return Valid registered replacement-recovery payload paths.
   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector;

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

   --  As Rename_Item, also telling where the entry was left when it is at
   --  neither name: a case-only rename goes through a scratch name beside
   --  the original, and when the second hop and the way back both fail the
   --  entry stays at that scratch name -- reported as Rename_Stranded_Key,
   --  whose message names Left_At.
   --
   --  @param From_Path Existing path.
   --  @param To_Path Destination path.
   --  @param Left_At The path the entry was left at for Rename_Stranded_Key;
   --    empty otherwise.
   --  @param Expected_Identity Optional history snapshot verified before and after quarantining the source.
   --  @return Mutation result.
   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Left_At   : out UString;
      Expected_Identity : String := "")
      return Mutation_Result;

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

   --  Change the permission bits of one verified entry through a handle that
   --  pins it, capturing the bits it had.
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

   --  Change_Mode as a user's edit makes it, reporting the entry's whole
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
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
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
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result;

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

   --  Execute a validated drag-and-drop import plan.
   --
   --  @param Plans Plans produced by Plan_Drop_Import.
   --  @param Cancel Optional callback requesting cancellation before source deletion.
   --  @param Batch Shared hard-link journal, created automatically for multiple plans.
   --  @return Mutation result with a localized error key on failure.
   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result;

   --  Execute while returning publication-time snapshots for each completed plan.
   --  @param Plans Validated copy or move plans.
   --  @param Created_Identities Entry identities parallel to completed plans.
   --  @param Created_Tree_Revisions Recursive directory revisions parallel to completed plans.
   --  @param Cancel Optional cooperative cancellation callback.
   --  @param Batch Shared hard-link journal.
   --  @return Mutation result with a localized error key on failure.
   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result;

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
   --  @param Cancel Optional cooperative cancellation callback.
   --  @param Batch Shared hard-link journal.
   --  @return Success when Destination holds the imported entry; otherwise
   --    the preserving, import, or restoring failure.
   function Import_Replacing
     (Source, Destination   : String;
      Mode                  : Drop_Import_Mode;
      Replace               : Boolean;
      Replaced              : out Files.Types.UString;
      Replaced_Identity     : out Files.Types.UString;
      Created_Identity      : out Files.Types.UString;
      Created_Tree_Revision : out Files.Types.UString;
      Preserved             : access procedure (Backup, Backup_Identity : String) := null;
      Cancel                : Cancellation_Check := null;
      Batch                 : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result;

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

end Files.File_System;
