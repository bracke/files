with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Interfaces.C;
with Interfaces.C.Strings;

with System;
with System.Address_To_Access_Conversions;

with GNAT.OS_Lib;

with Zlib;

with Files.File_Types;
with Files.Fs;
with Files_Config;

with Hostkit.Metadata;
with Hostkit.Fs;
with Hostkit.Host;
with Files.UTF8;
with Files.File_System.Support;
with Files.File_System.Recovery;
with Files.File_Identities;

package body Files.File_System is

   use Files.File_System.Support;
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   use type System.Address;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;

   package Thumbnails is
      function Default_Thumbnail_Cache_Directory
        (Fallback_Directory : String)
         return String;

      function Thumbnail_Path_For
        (Source_Path      : String;
         Cache_Directory : String;
         Size            : Positive := 64)
         return String;

      function Generate_Thumbnail
        (Source_Path      : String;
         Cache_Directory : String;
         Size            : Positive := 64)
         return Thumbnail_Result;

      function Decode_Image_To_Pixels
        (Path     : String;
         Max_Size : Positive)
         return Decoded_Image;

      function Is_Image_Item
        (Kind     : Files.Types.Item_Kind;
         Filetype : String;
         Name     : String;
         Icon_Id  : String)
         return Boolean;

      function Read_Preview_Text
        (Path      : String;
         Max_Bytes : Natural)
         return String;

      function Read_Preview_Text
        (Path : String; Max_Bytes : Natural; Success : out Boolean) return String;

      function Image_Bytes_Extent
        (Data   : Ada.Streams.Stream_Element_Array;
         Width  : out Natural;
         Height : out Natural)
         return Boolean;

      function Decode_Image_Bytes
        (Data : Ada.Streams.Stream_Element_Array)
         return Decoded_Image;

      procedure Prune_Thumbnail_Cache
        (Cache_Directory : String;
         Budget_Bytes    : Long_Long_Integer);
   end Thumbnails;
   package body Thumbnails is separate;

   --  The thumbnails operations now live in the
   --  Files.File_System.Thumbnails child; these renamings keep them on the public API.
   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
     renames Thumbnails.Default_Thumbnail_Cache_Directory;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String
     renames Thumbnails.Thumbnail_Path_For;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
     renames Thumbnails.Generate_Thumbnail;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
     renames Thumbnails.Decode_Image_To_Pixels;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
     renames Thumbnails.Is_Image_Item;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
     renames Thumbnails.Read_Preview_Text;

   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success : out Boolean) return String
     renames Thumbnails.Read_Preview_Text;

   function Image_Bytes_Extent
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
     renames Thumbnails.Image_Bytes_Extent;

   function Decode_Image_Bytes
     (Data : Ada.Streams.Stream_Element_Array)
      return Decoded_Image
     renames Thumbnails.Decode_Image_Bytes;

   procedure Prune_Thumbnail_Cache
     (Cache_Directory : String;
      Budget_Bytes    : Long_Long_Integer)
     renames Thumbnails.Prune_Thumbnail_Cache;

   package Directory is
      function Load_Directory
        (Path     : String;
         Settings : Files.Settings.Settings_Model)
         return Directory_Load_Result;

      function Load_Item
        (Full_Path : String;
         Settings  : Files.Settings.Settings_Model)
         return Item_Load_Result;

      function Extra_Info_Token
        (Path     : String;
         Kind     : Files.Types.Item_Kind;
         Filetype : String)
         return String;

      procedure Sort_Items
        (Items     : in out Item_Vectors.Vector;
         Field     : Files.Settings.Sort_Field;
         Ascending : Boolean);

      function Directory_State
        (Path : String)
         return Directory_Signature;

      function Detect_Directory_Change
        (Before_State : Directory_Signature;
         Path         : String)
         return Directory_Change_Result;

      function Directory_Size
        (Path        : String;
         Max_Entries : Natural := 50_000;
         Max_Depth   : Natural := 64)
         return Directory_Size_Result;

      function Make_Item
        (Parent_Path : String;
         Name        : String;
         Kind        : Files.Types.Item_Kind;
         Filetype    : String := "")
         return Directory_Item;

      function Make_Item
        (Parent_Path : String;
         Name        : String;
         Kind        : Files.Types.Item_Kind;
         Settings    : Files.Settings.Settings_Model)
         return Directory_Item;
   end Directory;
   package body Directory is separate;

   --  The directory operations now live in the
   --  Files.File_System.Directory child; these renamings keep them on the public API.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result
     renames Directory.Load_Directory;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
     renames Directory.Load_Item;

   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String
     renames Directory.Extra_Info_Token;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
     renames Directory.Sort_Items;

   function Directory_State
     (Path : String)
      return Directory_Signature
     renames Directory.Directory_State;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
     renames Directory.Detect_Directory_Change;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
     renames Directory.Directory_Size;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item
     renames Directory.Make_Item;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
     renames Directory.Make_Item;

   function Is_Directory (Item : Directory_Item) return Boolean is
   begin
      return Item.Kind = Files.Types.Directory_Item;
   end Is_Directory;

   package Trash is
      function Trash_Is_Available return Boolean;

      function Trash_Backend_Of_Current_Environment return Trash_Backend;

      function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities;

      function Native_Trash_Request_For
        (Path : String)
         return Native_Trash_Request;

      function Evaluate_Native_Trash
        (Request : Native_Trash_Request)
         return Native_Trash_Result;

      function Execute_Native_Trash
        (Request : Native_Trash_Request)
         return Native_Trash_Result;

      function Move_To_Trash_Preflight
        (Path : String)
         return Mutation_Result;

      function Trash_Deletion_Date
        (Value : Ada.Calendar.Time)
         return String;

      function Trash_Files_Directory return String;

      function Original_Path (Trashed_Path : String) return String;

      function Restore_From_Trash
        (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
         return Mutation_Result;

      function Move_To_Trash
        (Path : String)
         return Mutation_Result;

      function Move_To_Trash
        (Path         : String;
         Trashed_Path : out Files.Types.UString)
         return Mutation_Result;

      function Delete_Trashed_Item
        (Trashed_Path : String)
         return Mutation_Result;
   end Trash;
   package body Trash is separate;

   --  The trash operations now live in the
   --  Files.File_System.Trash child; these renamings keep them on the public API.
   function Trash_Is_Available return Boolean
     renames Trash.Trash_Is_Available;

   function Trash_Backend_Of_Current_Environment return Trash_Backend
     renames Trash.Trash_Backend_Of_Current_Environment;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities
     renames Trash.Trash_Capabilities_Of_Current_Environment;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
     renames Trash.Native_Trash_Request_For;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Trash.Evaluate_Native_Trash;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Trash.Execute_Native_Trash;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
     renames Trash.Move_To_Trash_Preflight;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
     renames Trash.Trash_Deletion_Date;

   function Trash_Files_Directory return String
     renames Trash.Trash_Files_Directory;

   function Trash_Original_Path (Trashed_Path : String) return String is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Original_Path (Trashed_Path);
      end if;
      return Trash.Original_Path (Trashed_Path);
   end Trash_Original_Path;

   function Is_Recovery_Payload (Path : String) return Boolean
     renames Recovery.Recognizes;

   function Registered_Recovery_Payloads return Files.Types.String_Vectors.Vector
     renames Recovery.Registered_Payloads;

   function Restore_From_Trash
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result
   is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Restore (Trashed_Path, Expected_Identity, Expected_Original);
      end if;
      return Trash.Restore_From_Trash (Trashed_Path, Expected_Identity, Expected_Original);
   end Restore_From_Trash;

   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
   is
   begin
      if Trash.Trash_Backend_Of_Current_Environment in Trash_Xdg_Data_Home | Trash_Home_Data then
         return Trash.Move_To_Trash (Path, Recovery_Path);
      end if;
      return Recovery.Preserve (Path, Recovery_Path);
   end Preserve_For_Replace;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
     renames Trash.Move_To_Trash;

   function Move_To_Trash
     (Path         : String;
      Trashed_Path : out Files.Types.UString)
      return Mutation_Result
     renames Trash.Move_To_Trash;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Discard (Trashed_Path);
      end if;
      return Trash.Delete_Trashed_Item (Trashed_Path);
   end Delete_Trashed_Item;

   package Path is
      function Normalize_Path
        (Path : String)
         return Path_Result;

      function Expand_User_Path (Path : String) return String;

      function Parent_Directory
        (Path : String)
         return String;

      function Join_Path
        (Parent_Path : String;
         Name        : String)
         return String;

      function Valid_Leaf_Name
        (Name  : String;
         Rules : Name_Rules := Host_Rules)
         return Boolean;

      function Valid_Leaf_Name_At
        (Name      : String;
         Directory : String)
         return Boolean;

      function Next_Untitled_Name
        (Directory_Path : String)
         return String;
   end Path;
   package body Path is separate;

   --  The path operations now live in the
   --  Files.File_System.Path child; these renamings keep them on the public API.
   function Normalize_Path
     (Path : String)
      return Path_Result
     renames Path.Normalize_Path;

   function Expand_User_Path (Path : String) return String
     renames Path.Expand_User_Path;

   function Parent_Directory
     (Path : String)
      return String
     renames Path.Parent_Directory;

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String
     renames Path.Join_Path;

   function Valid_Leaf_Name
     (Name  : String;
      Rules : Name_Rules := Host_Rules)
      return Boolean
     renames Path.Valid_Leaf_Name;

   function Valid_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
     renames Path.Valid_Leaf_Name_At;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
     renames Path.Next_Untitled_Name;

   package Search is
      function Search_Recursive
        (Root_Path : String;
         Query     : String;
         Settings  : Files.Settings.Settings_Model;
         Max_Items : Natural := 1_000)
         return Recursive_Search_Result;
   end Search;
   package body Search is separate;

   --  The search operations now live in the
   --  Files.File_System.Search child; these renamings keep them on the public API.
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
     renames Search.Search_Recursive;

   package Roots is
      function Available_Roots return Files.Types.String_Vectors.Vector;

      function Available_Root_Entries return Root_Entry_Vectors.Vector;

      function Root_Label (Path : String; Kind : Root_Kind) return String;

      function Root_Discovery_Status return Root_Discovery_Diagnostics;

      function Root_Volume_Capabilities_Of_Current_Environment
         return Root_Volume_Capabilities;

      function Filesystem_Edge_Case_Profile_Of_Current_Environment
         return Filesystem_Edge_Case_Profile;

      function Native_Platform_API_Profile_For
        (Adapter : Native_Platform_Adapter)
         return Native_Platform_API_Profile;

      function Root_Volume_Details_For
        (Root : Root_Entry)
         return Root_Volume_Details;

      function Filetype_Metadata_Policy_Of_Current_Implementation
         return Filetype_Metadata_Policy;
   end Roots;
   package body Roots is separate;

   --  The roots operations now live in the
   --  Files.File_System.Roots child; these renamings keep them on the public API.
   function Available_Roots return Files.Types.String_Vectors.Vector
     renames Roots.Available_Roots;

   function Available_Root_Entries return Root_Entry_Vectors.Vector
     renames Roots.Available_Root_Entries;

   function Root_Label (Path : String; Kind : Root_Kind) return String
     renames Roots.Root_Label;

   function Root_Discovery_Status return Root_Discovery_Diagnostics
     renames Roots.Root_Discovery_Status;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities
     renames Roots.Root_Volume_Capabilities_Of_Current_Environment;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile
     renames Roots.Filesystem_Edge_Case_Profile_Of_Current_Environment;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
     renames Roots.Native_Platform_API_Profile_For;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
     renames Roots.Root_Volume_Details_For;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy
     renames Roots.Filetype_Metadata_Policy_Of_Current_Implementation;

   package Create is
      function Create_Empty_File
        (Path : String)
         return Mutation_Result;

      function Create_Directory
        (Path : String)
         return Mutation_Result;

      function Rename_Item
        (From_Path : String;
         To_Path   : String;
         Expected_Identity : String := "")
         return Mutation_Result;

      function Create_Symbolic_Link
        (Source_Path : String;
         Link_Path   : String)
         return Mutation_Result;

      function Create_Hard_Link
        (Source_Path : String;
         Link_Path   : String)
         return Mutation_Result;
   end Create;
   package body Create is separate;

   --  The create operations now live in the
   --  Files.File_System.Create child; these renamings keep them on the public API.
   function Create_Empty_File
     (Path : String)
      return Mutation_Result
     renames Create.Create_Empty_File;

   function Create_Directory
     (Path : String)
      return Mutation_Result
     renames Create.Create_Directory;

   function Rename_Item
     (From_Path : String;
      To_Path   : String;
      Expected_Identity : String := "")
      return Mutation_Result
     renames Create.Rename_Item;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     renames Create.Create_Symbolic_Link;

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     renames Create.Create_Hard_Link;

   package Permissions is
      function Supports_Permissions return Boolean;

      function Permission_Bits_Of
        (Path      : String;
         Available : out Boolean)
         return Natural;

      function Set_Permissions
        (Path : String;
         Mode : Natural)
         return Mutation_Result;

      function Supports_Ownership return Boolean;

      procedure Ownership_Of
        (Path      : String;
         User_Id   : out Natural;
         Group_Id  : out Natural;
         Available : out Boolean);

      function Set_Ownership
        (Path     : String;
         User_Id  : Natural;
         Group_Id : Natural)
         return Mutation_Result;

      function User_Id_For_Name
        (Name  : String;
         Found : out Boolean)
         return Natural;

      function Group_Id_For_Name
        (Name  : String;
         Found : out Boolean)
         return Natural;

      function User_Name_For_Id (Id : Natural) return String;

      function Group_Name_For_Id (Id : Natural) return String;
   end Permissions;
   package body Permissions is separate;

   --  The permissions operations now live in the
   --  Files.File_System.Permissions child; these renamings keep them on the public API.
   function Supports_Permissions return Boolean
     renames Permissions.Supports_Permissions;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural
     renames Permissions.Permission_Bits_Of;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
     renames Permissions.Set_Permissions;

   function Supports_Ownership return Boolean
     renames Permissions.Supports_Ownership;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean)
     renames Permissions.Ownership_Of;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
     renames Permissions.Set_Ownership;

   function Change_Metadata
     (Path, Expected_Identity : String; Ownership : Boolean; Value, Group : Natural;
      Previous, Previous_Group : out Natural; Identity : out Files.Types.UString) return Mutation_Result
   is
      subtype U64 is Interfaces.C.unsigned_long_long;
      type Native_Identity is record
         Volume, Number, Seconds, Nanoseconds : U64;
      end record with Convention => C;
      function Update
        (Path, Expected : System.Address; Ownership : Interfaces.C.int;
         Value, Group : Interfaces.C.unsigned_long;
         Owner_Name, Group_Name : System.Address;
         Previous, Previous_Group : access U64;
         Identity : access Native_Identity) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_metadata_update";
      Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      Expected : aliased Interfaces.C.char_array := Interfaces.C.To_C (Expected_Identity);
      Owner_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C
        ((if Ownership then Permissions.User_Name_For_Id (Value) else ""));
      Group_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C
        ((if Ownership then Permissions.Group_Name_For_Id (Group) else ""));
      Old_Value, Old_Group : aliased U64 := 0;
      Entry_Id : aliased Native_Identity;
      Status : Interfaces.C.int;
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String
          (if Ownership then "error.ownership.denied" else "error.permissions.failed"));
   begin
      Previous := 0;
      Previous_Group := 0;
      Identity := Null_Unbounded_String;
      Status := Update (Name'Address, Expected'Address, Boolean'Pos (Ownership),
                        Interfaces.C.unsigned_long (Value), Interfaces.C.unsigned_long (Group),
                        Owner_Name'Address, Group_Name'Address,
                        Old_Value'Access, Old_Group'Access, Entry_Id'Access);
      if Status = 1 then
         Previous := Natural (Old_Value);
         Previous_Group := Natural (Old_Group);
         Identity := To_Unbounded_String (U64'Image (Entry_Id.Volume) & U64'Image (Entry_Id.Number)
           & U64'Image (Entry_Id.Seconds) & U64'Image (Entry_Id.Nanoseconds));
         return (Success => True, Error_Key => Null_Unbounded_String);
      elsif Status = 0 then
         return Failed;
      end if;
      --  Never emulate a handle-relative metadata update by checking a path,
      --  mutating it by name, and checking again: another process can replace
      --  the entry in between. Platforms without the native atomic adapter
      --  therefore fail closed.
      return Failed;
   exception
      when others => return Failed;
   end Change_Metadata;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     renames Permissions.User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     renames Permissions.Group_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String
     renames Permissions.User_Name_For_Id;

   function Group_Name_For_Id (Id : Natural) return String
     renames Permissions.Group_Name_For_Id;

   package Copy_Move is
      function Copy_Tree
        (Source_Path      : String;
         Destination_Path : String;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
         return Mutation_Result;

      function Copy_Tree
        (Source_Path, Destination_Path : String;
         Identity, Tree_Revision_Value : out Files.Types.UString;
         Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
         return Mutation_Result;

      function Delete_Permanently
        (Path : String)
         return Mutation_Result;

      function Plan_Drop_Import
        (Source_Paths          : Files.Types.String_Vectors.Vector;
         Destination_Directory : String;
         Mode                  : Drop_Import_Mode := Drop_Copy)
         return Drop_Import_Result;

      function Execute_Drop_Import
        (Plans  : Drop_Import_Plan_Vectors.Vector;
         Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
         return Mutation_Result;

      function Execute_Drop_Import
        (Plans  : Drop_Import_Plan_Vectors.Vector;
         Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
         Cancel : Cancellation_Check := null;
         Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
         return Mutation_Result;
   end Copy_Move;
   package body Copy_Move is separate;

   --  The copy move operations now live in the
   --  Files.File_System.Copy_Move child; these renamings keep them on the public API.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Copy_Move.Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Copy_Move.Copy_Tree;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
     renames Copy_Move.Delete_Permanently;

   function Delete_Verified_Entry
     (Path : String;
      Expected_Identity, Expected_Tree_Revision : String;
      Verify_Tree : Boolean) return Mutation_Result
   is
      Backup : UString;
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.undo.failed"));
   begin
      if Expected_Identity = "" or else Files.File_Identities.Token (Path) /= Expected_Identity then
         return Failed;
      end if;
      if Verify_Tree and then not Hostkit.Fs.Is_Link (Path)
        and then (Expected_Tree_Revision = "" or else Tree_Revision (Path) /= Expected_Tree_Revision)
      then
         return Failed;
      end if;
      if not Recovery.Preserve (Path, Backup).Success then
         return Failed;
      end if;
      --  Verify after the atomic rename as well: an entry substituted between
      --  the first check and quarantine must never have its contents deleted.
      if Files.File_Identities.Token (To_String (Backup)) /= Expected_Identity then
         declare
            Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
            pragma Unreferenced (Restored);
         begin
            return Failed;
         end;
      end if;
      if Verify_Tree and then not Hostkit.Fs.Is_Link (To_String (Backup))
        and then Tree_Revision (To_String (Backup)) /= Expected_Tree_Revision
      then
         declare
            Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
            pragma Unreferenced (Restored);
         begin
            return Failed;
         end;
      end if;
      declare
         Removed : Boolean := False;
      begin
         begin
            Support.Delete_Owned_Tree (To_String (Backup));
            Removed := True;
         exception
            when others => null;
         end;
         if not Removed then
            declare
               Restored : constant Mutation_Result := Recovery.Restore (To_String (Backup));
               pragma Unreferenced (Restored);
            begin
               return Failed;
            end;
         end if;
      end;
      declare
         Removed : constant Mutation_Result := Delete_Permanently (Ada.Directories.Containing_Directory
           (To_String (Backup)));
         pragma Unreferenced (Removed);
      begin
         return (Success => True, Error_Key => Null_Unbounded_String);
      end;
   exception
      when others => return Failed;
   end Delete_Verified_Entry;

   function Delete_Created_Entry
     (Path : String; Expected_Identity, Expected_Tree_Revision : String) return Mutation_Result is
   begin
      return Delete_Verified_Entry
        (Path, Expected_Identity, Expected_Tree_Revision, Verify_Tree => True);
   end Delete_Created_Entry;

   function Delete_Staging_Entry
     (Path : String; Expected_Identity : String) return Mutation_Result is
   begin
      return Delete_Verified_Entry
        (Path, Expected_Identity, "", Verify_Tree => False);
   end Delete_Staging_Entry;

   function Tree_Revision (Path : String) return String is
   begin
      return Support.Tree_Revision (Path);
   exception
      when others => return "";
   end Tree_Revision;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
     renames Copy_Move.Plan_Drop_Import;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Copy_Move.Execute_Drop_Import;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
     renames Copy_Move.Execute_Drop_Import;

end Files.File_System;
