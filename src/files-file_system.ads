with Ada.Calendar;
with Ada.Containers.Vectors;

with Files.Settings;
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

   type Directory_Item is record
      Name               : UString;
      Full_Path          : UString;
      Parent_Path        : UString;
      Kind               : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Filetype           : UString;
      Icon_Id            : UString;
      Size_Available     : Boolean := False;
      Size               : Long_Long_Integer := 0;
      Creation_Available : Boolean := False;
      Creation_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Modified_Available : Boolean := False;
      Modified_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Permissions        : UString;
      Mode_Available     : Boolean := False;
      Mode_Bits          : Natural := 0;
      Ownership_Available : Boolean := False;
      Owner_Id           : Natural := 0;
      Group_Id           : Natural := 0;
      Filetype_Extra     : UString;
      Thumbnail_Available : Boolean := False;
      Thumbnail_Path      : UString;
      Thumbnail_Width     : Natural := 0;
      Thumbnail_Height    : Natural := 0;
      Thumbnail_Pixels    : Files.Types.Byte_Vectors.Vector;
      Metadata_Error     : Boolean := False;
      Error_Key          : UString;
   end record;

   package Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Directory_Item);

   type Directory_Load_Result is record
      Success   : Boolean := False;
      Path      : UString;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
   end record;

   type Recursive_Search_Result is record
      Success   : Boolean := False;
      Root_Path : UString;
      Query     : UString;
      Items     : Item_Vectors.Vector;
      Error_Key : UString;
   end record;

   type Directory_Signature is record
      Path               : UString;
      Exists             : Boolean := False;
      Entry_Count        : Natural := 0;
      Entry_State_Checksum : Natural := 0;
      Latest_Modified    : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Latest_Modified_Known : Boolean := False;
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

   type Thumbnail_Status is
     (Thumbnail_Generated,
      Thumbnail_Source_Missing,
      Thumbnail_Unsupported,
      Thumbnail_Failed);

   type Thumbnail_Result is record
      Status         : Thumbnail_Status := Thumbnail_Failed;
      Source_Path    : UString;
      Thumbnail_Path : UString;
      Width          : Positive := 1;
      Height         : Positive := 1;
      Error_Key      : UString;
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

   type Native_API_Binding_Status is
     (Native_API_Not_Target,
      Native_API_Binding_Missing,
      Native_API_Binding_Available);

   type Native_Platform_Adapter is
     (Native_Adapter_None,
      Native_Adapter_Linux,
      Native_Adapter_Windows,
      Native_Adapter_Macos);

   type Native_Platform_API_Profile is record
      Adapter                 : Native_Platform_Adapter := Native_Adapter_None;
      Trash_Binding_Status    : Native_API_Binding_Status := Native_API_Not_Target;
      Volume_Binding_Status   : Native_API_Binding_Status := Native_API_Not_Target;
      Trash_API_Name          : UString;
      Volume_API_Name         : UString;
      Trash_Binding_Unit      : UString;
      Volume_Binding_Unit     : UString;
      Required_Library        : UString;
      Required_Framework      : UString;
      Current_Target          : Boolean := False;
      Trash_Can_Execute       : Boolean := False;
      Volume_Can_Query        : Boolean := False;
   end record;

   type Trash_Capabilities is record
      Backend             : Trash_Backend := Trash_Unavailable;
      Native_Platform     : Boolean := False;
      Xdg_Compatible      : Boolean := False;
      Metadata_Sidecar    : Boolean := False;
      Collision_Safe_Name : Boolean := False;
      Permanent_Delete    : Boolean := False;
      Native_Diagnostics  : Boolean := True;
      Multi_Item_Preflight : Boolean := True;
   end record;

   type Native_Trash_Request is record
      Backend                 : Trash_Backend := Trash_Unavailable;
      Path                    : UString;
      Requires_Native_Api     : Boolean := False;
      Can_Use_Current_Process : Boolean := False;
   end record;

   type Native_Trash_Result is record
      Supported        : Boolean := False;
      Attempted        : Boolean := False;
      Completed        : Boolean := False;
      Native_Binding_Available : Boolean := False;
      Native_Binding_Status : Native_API_Binding_Status := Native_API_Not_Target;
      Binding_Unit    : UString;
      Desktop_Standard : Boolean := False;
      Would_Delete     : Boolean := False;
      Uses_Recycle_Bin : Boolean := False;
      Adapter_Name     : UString;
      Native_Api_Name  : UString;
      Operation_Name   : UString;
      Requires_User_Consent : Boolean := False;
      Preserves_Metadata    : Boolean := False;
      Error_Key        : UString;
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
      Label : UString;
      Kind  : Root_Kind := Root_Filesystem;
      Volume_Name : UString;
      Ready       : Root_Readiness := Root_Ready;
      Removable   : Boolean := False;
   end record;

   package Root_Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Root_Entry);

   type Root_Discovery_Diagnostics is record
      Root_Count              : Natural := 0;
      Ready_Count             : Natural := 0;
      Removable_Count         : Natural := 0;
      Windows_Drive_Count     : Natural := 0;
      Mount_Count             : Natural := 0;
      User_Mount_Count        : Natural := 0;
      Network_Mount_Count     : Natural := 0;
      Duplicate_Paths_Removed : Boolean := True;
      Deterministic_Order     : Boolean := True;
   end record;

   type Root_Volume_Capabilities is record
      Labels_From_Platform_Api    : Boolean := False;
      Readiness_From_Platform_Api : Boolean := False;
      Removable_From_Platform_Api : Boolean := False;
      Capacity_From_Platform_Api  : Boolean := False;
      Filesystem_Type_Available   : Boolean := False;
      Eject_Available             : Boolean := False;
      Native_Api_Name             : UString;
      Native_Binding_Status       : Native_API_Binding_Status := Native_API_Not_Target;
      Binding_Unit                : UString;
      Source_Device_Available     : Boolean := False;
      Mount_Options_Available     : Boolean := False;
      Network_Metadata_Available  : Boolean := False;
      Removable_Status_Available  : Boolean := False;
      Capacity_Bytes_Known        : Boolean := False;
      Free_Bytes_Known            : Boolean := False;
      Inode_Count_Known           : Boolean := False;
      Read_Only_Available         : Boolean := False;
      Name_Max_Available          : Boolean := False;
   end record;

   type Filesystem_Edge_Case_Profile is record
      Permission_Errors_Recoverable : Boolean := True;
      Symlink_Items_Represented     : Boolean := True;
      Special_File_Items_Represented : Boolean := True;
      Cross_Device_Rename_Recoverable : Boolean := True;
      Trash_Preflight               : Boolean := True;
      Metadata_Partial_Items        : Boolean := True;
      Removable_Root_Metadata       : Boolean := True;
      Native_Root_Volume_Details    : Boolean := True;
   end record;

   type Root_Volume_Details is record
      Path                 : UString;
      Label                : UString;
      Native_Api_Name      : UString;
      Filesystem_Type      : UString;
      Source_Device        : UString;
      Mount_Options        : UString;
      Capacity_Bytes       : Long_Long_Integer := 0;
      Free_Bytes           : Long_Long_Integer := 0;
      Inode_Count          : Long_Long_Integer := 0;
      Free_Inode_Count     : Long_Long_Integer := 0;
      Capacity_Known       : Boolean := False;
      Free_Known           : Boolean := False;
      Inode_Count_Known    : Boolean := False;
      Free_Inode_Known     : Boolean := False;
      Read_Only            : Boolean := False;
      Read_Only_Known      : Boolean := False;
      Name_Max             : Natural := 0;
      Name_Max_Known       : Boolean := False;
      Removable_Known      : Boolean := False;
      Removable            : Boolean := False;
      Ejectable            : Boolean := False;
      Network_Mount        : Boolean := False;
      Remote_Protocol      : UString;
      Offline_Possible     : Boolean := False;
      Auth_May_Be_Required : Boolean := False;
      Latency_Sensitive    : Boolean := False;
      Special_Error_Recovery : Boolean := False;
      Uses_Platform_Detail : Boolean := False;
   end record;

   type Filetype_Metadata_Policy is record
      Uses_Extension_Mapping     : Boolean := True;
      Uses_Mime_Sniffing         : Boolean := False;
      Parses_Image_Dimensions    : Boolean := True;
      Parses_Text_Encoding       : Boolean := True;
      Parses_Archive_Entry_Count : Boolean := True;
      Parses_Pdf_Page_Markers    : Boolean := True;
      Parses_Media_Codecs        : Boolean := False;
      Parses_Office_Package_Info : Boolean := True;
   end record;

   --  Normalize an existing filesystem path to a directory path.
   --
   --  @param Path Path supplied by a user or command line.
   --  @return Path validation result and normalized directory path when valid.
   function Normalize_Path
     (Path : String)
      return Path_Result;

   --  Return the parent directory of Path.
   --
   --  @param Path Directory path whose parent is requested.
   --  @return Parent directory path, or an empty string when Path is a
   --    filesystem root (or otherwise has no parent).
   function Parent_Directory
     (Path : String)
      return String;

   --  Load the direct children of a directory.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

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
      Field     : Files.Settings.Sort_Field;
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

   --  Return available filesystem root locations in deterministic order.
   --
   --  @return Root paths available on the host platform.
   function Available_Roots return Files.Types.String_Vectors.Vector;

   --  Return available filesystem root locations with labels and source kind.
   --
   --  @return Root entries available on the host platform.
   function Available_Root_Entries return Root_Entry_Vectors.Vector;

   --  Return the display-label token for a root location. The token is either a
   --  localization key (e.g. "root.home") or a "key|value" pair the renderer
   --  expands with a localized prefix and suffix (e.g. "root.favorite|<name>").
   --
   --  @param Path Root path.
   --  @param Kind Root classification.
   --  @return Label token for the renderer.
   function Root_Label (Path : String; Kind : Root_Kind) return String;

   --  Return diagnostics for root discovery without changing the root list.
   --
   --  @return Root discovery counts and policy flags.
   function Root_Discovery_Status return Root_Discovery_Diagnostics;

   --  Return root volume metadata capabilities for the current implementation.
   --
   --  @return Platform volume metadata capability flags.
   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities;

   --  Return filesystem edge-case handling metadata for the current implementation.
   --
   --  @return Recoverable filesystem edge-case behavior flags.
   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile;

   --  Return native filesystem adapter capabilities for the selected platform.
   --
   --  @param Adapter Platform adapter to inspect.
   --  @return Native trash and volume API binding status for Adapter.
   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile;

   --  Return best-effort volume details for a discovered root.
   --
   --  @param Root Root entry to describe.
   --  @return Volume details and known platform metadata flags.
   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details;

   --  Return filetype metadata extraction policy for the current implementation.
   --
   --  @return Metadata extraction capability flags.
   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy;

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

   --  Join a parent directory path and a simple child name.
   --
   --  @param Parent_Path Parent directory path.
   --  @param Name Child name.
   --  @return Joined path using the host directory separator.
   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String;

   --  Return whether Name is a safe leaf filename for create or rename.
   --
   --  @param Name Candidate filename without parent path components.
   --  @return True when Name can be used as a direct child filename.
   function Valid_Leaf_Name
     (Name : String)
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

   --  Return the trash backend selected for the current environment.
   --
   --  @return Backend that Move_To_Trash will use, or Trash_Unavailable.
   function Trash_Backend_Of_Current_Environment return Trash_Backend;

   --  Return trash backend capabilities for the current environment.
   --
   --  @return Structured trash capability description.
   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities;

   --  Build the native trash request that would be needed for Path.
   --
   --  @param Path Filesystem path requested for native trash handling.
   --  @return Native trash request metadata.
   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request;

   --  Evaluate native trash support for Request without deleting anything.
   --
   --  @param Request Native trash request metadata.
   --  @return Native trash support result.
   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

   --  Execute a trash request through the selected backend when supported.
   --
   --  @param Request Native trash request metadata.
   --  @return Trash execution result with adapter diagnostics.
   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result;

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

   --  Format a timestamp for freedesktop trashinfo DeletionDate metadata.
   --
   --  @param Value Time value to format.
   --  @return Local timestamp in YYYY-MM-DDTHH:MM:SS form.
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String;

   --  Return the directory that holds trashed payloads for the current backend.
   --
   --  This is <Trash_Base_Path>/files for the freedesktop XDG and home-data
   --  backends, and <Trash_Base_Path> itself for the macOS flat home backend.
   --
   --  @return Trashed-payload directory, or an empty string when unavailable.
   function Trash_Files_Directory return String;

   --  Restore a trashed payload to its recorded original location.
   --
   --  For freedesktop backends the original path is read from the matching
   --  <base>/info/<name>.trashinfo sidecar, URL-decoded, and the payload is
   --  moved back; the sidecar is removed on success. Backends without a sidecar
   --  fail with error.trash.restore_unavailable.
   --
   --  @param Trashed_Path Payload path inside the trash files directory.
   --  @return Mutation result with a localized error key on failure.
   function Restore_From_Trash
     (Trashed_Path : String)
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
   --  @return Mutation result.
   function Rename_Item
     (From_Path : String;
      To_Path   : String)
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

   --  Return the numeric owner (UID) and group (GID) of Path.
   --
   --  @param Path Existing filesystem path to inspect.
   --  @param User_Id Set to the owning user id when Available is True.
   --  @param Group_Id Set to the owning group id when Available is True.
   --  @param Available Set True when the ownership ids were obtained.
   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean);

   --  Change the owner and group of an existing entry through chown(2).
   --
   --  The path must already exist. Because changing ownership usually requires
   --  root privileges, an unprivileged failure maps to error.ownership.denied,
   --  and an unsupported platform maps to error.ownership.unsupported.
   --
   --  @param Path Existing filesystem path whose ownership is changed.
   --  @param User_Id New owning user id to apply.
   --  @param Group_Id New owning group id to apply.
   --  @return Mutation result with a localized error key on failure.
   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result;

   --  Resolve a user name to its numeric id (getpwnam).
   --
   --  @param Name User name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The user id when Found, otherwise 0.
   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural;

   --  Resolve a group name to its numeric id (getgrnam).
   --
   --  @param Name Group name to resolve.
   --  @param Found Set True when the name resolved to an id.
   --  @return The group id when Found, otherwise 0.
   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural;

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
   --  @return Mutation result with a localized error key on failure.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
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
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path         : String;
      Trashed_Path : out Files.Types.UString)
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

   --  Permanently delete a single trashed payload and its metadata.
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

   --  Execute a validated drag-and-drop import plan.
   --
   --  @param Plans Plans produced by Plan_Drop_Import.
   --  @return Mutation result with a localized error key on failure.
   function Execute_Drop_Import
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result;

   --  Return the default thumbnail cache directory for the current environment.
   --
   --  @param Fallback_Directory Directory used when no user cache location exists.
   --  @return Directory path used for generated thumbnail artifacts.
   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String;

   --  Return the deterministic cached thumbnail path for a source file.
   --
   --  @param Source_Path Source file represented by the thumbnail.
   --  @param Cache_Directory Thumbnail cache directory.
   --  @param Size Thumbnail size in pixels.
   --  @return Deterministic thumbnail artifact path.
   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String;

   --  Generate a cached thumbnail artifact for a regular file.
   --
   --  Supported source image formats are decoded and scaled in Ada; unsupported
   --  formats fall back to a deterministic PPM derived from file metadata.
   --
   --  @param Source_Path File to summarize as a thumbnail.
   --  @param Cache_Directory Directory where the thumbnail file is written.
   --  @param Size Width and height in pixels.
   --  @return Thumbnail path and status, or a recoverable error key.
   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result;

   --  Return whether an item is a previewable raster image, using the same
   --  classification the automatic thumbnail generator applies (image/* MIME,
   --  the "image" icon id, or a known raster extension). Directories and
   --  symlinks are never images.
   --
   --  @param Kind Filesystem item kind.
   --  @param Filetype Detected filetype identifier.
   --  @param Name File name to inspect.
   --  @param Icon_Id Icon identifier for the item.
   --  @return True when the item should be previewed as an image.
   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

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
end Files.File_System;
