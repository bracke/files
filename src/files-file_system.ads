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
      Filetype_Extra     : UString;
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

   type Mutation_Result is record
      Success   : Boolean := False;
      Error_Key : UString;
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
      Root_Windows_Drive);

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

   --  Load the direct children of a directory.
   --
   --  @param Path Directory path to load.
   --  @param Settings Settings used for filetype and icon classification.
   --  @return Loaded directory model or a recoverable error result.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result;

   --  Return available filesystem root locations in deterministic order.
   --
   --  @return Root paths available on the host platform.
   function Available_Roots return Files.Types.String_Vectors.Vector;

   --  Return available filesystem root locations with labels and source kind.
   --
   --  @return Root entries available on the host platform.
   function Available_Root_Entries return Root_Entry_Vectors.Vector;

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

   --  Create an empty regular file without replacing an existing entry.
   --
   --  @param Path File path to create.
   --  @return Mutation result.
   function Create_Empty_File
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

   --  Move an entry to trash when a supported trash backend is available.
   --
   --  @param Path Entry to move to trash.
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path : String)
      return Mutation_Result;
end Files.File_System;
