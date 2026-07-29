with Ada.Characters.Handling;
with Ada.Containers.Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
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

with Files.Platform.Macos;
with Files.Platform.Metadata;
with Hostkit.Fs;
with Files.Platform.Macos.Trash;
with Files.Platform.Windows.Trash;
with Files.Platform.Windows;
with Files.UTF8;
with Files.File_System.Support;
with Files.Platform;
with Ada.Characters;

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

   --  The thumbnails operations are subunits of Files.File_System.
   --  Hoisted from the former Path child (now subunits).
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Permissions child (now subunits).
   use Ada.Strings.Unbounded;

   --  Session cache for numeric-id -> name resolution. Build_Snapshot resolves
   --  the selected items' owner/group names every frame, so memoize each id's
   --  name (including an unresolved "") to avoid repeated getpwuid/getgrgid.
   package Id_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Natural,
      Element_Type => Unbounded_String);
   User_Name_Cache  : Id_Name_Maps.Map;
   Group_Name_Cache : Id_Name_Maps.Map;

   --  Hoisted from the former Search child (now subunits).
   use Ada.Strings.Unbounded;

   use type Files.Types.Item_Kind;

   --  Hoisted from the former Create child (now subunits).
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   use type Ada.Directories.File_Kind;

   --  Hoisted from the former Trash child (now subunits).
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   use type Ada.Directories.File_Kind;

   --  Hoisted from the former Copy_Move child (now subunits).
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   --  Hoisted from the former Directory child (now subunits).
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
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;

   --  Hoisted from the former Thumbnails child (now subunits).
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Directories.File_Kind;

   use type Files.Types.Item_Kind;
   use type System.Address;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   --  Hoisted from the former Roots child (now subunits).
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   use type Ada.Directories.File_Kind;
   type Volume_Size_Info is record
      Capacity_Bytes   : Long_Long_Integer := 0;
      Free_Bytes       : Long_Long_Integer := 0;
      Inode_Count      : Long_Long_Integer := 0;
      Free_Inode_Count : Long_Long_Integer := 0;
      Name_Max         : Natural := 0;
      Read_Only        : Boolean := False;
      Known            : Boolean := False;
      Inodes_Known     : Boolean := False;
      Name_Max_Known   : Boolean := False;
      Read_Only_Known  : Boolean := False;
   end record;

   type Mount_Metadata is record
      Source_Device   : Unbounded_String;
      Filesystem_Type : Unbounded_String;
      Mount_Options   : Unbounded_String;
      Removable       : Boolean := False;
      Removable_Known : Boolean := False;
      Found           : Boolean := False;
   end record;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info)
 is separate;

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String
 is separate;

   function Simple_Device_Name (Source : String) return String is separate;

   function Parent_Block_Device_Name (Device : String) return String is separate;

   function Read_First_Line (Path : String) return String is separate;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean
 is separate;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is separate;

   function Gdk_Pixbuf_New_From_File_At_Size
     (Filename : Interfaces.C.Strings.chars_ptr;
      Width    : C_Int;
      Height   : C_Int;
      Error    : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_new_from_file_at_size";

   function Gdk_Pixbuf_Get_Width
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_width";

   function Gdk_Pixbuf_Get_Height
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_height";

   function Gdk_Pixbuf_Get_N_Channels
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_n_channels";

   function Gdk_Pixbuf_Get_Rowstride
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_rowstride";

   function Gdk_Pixbuf_Get_Pixels
     (Pixbuf : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_pixels";

   procedure G_Object_Unref
     (Object : System.Address)
   with Import, Convention => C, External_Name => "g_object_unref";

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is separate;

   function Thumbnail_Extension
     (Source_Path : String)
      return String
 is separate;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
 is separate;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
 is separate;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is separate;

   Extra_Line_Limit : constant Natural := 20_000;

   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   --  Leading magic bytes that identify a file format, one per row.
   ELF_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 4) :=
     [16#7F#, 16#45#, 16#4C#, 16#46#];   --  7F 'E' 'L' 'F'
   PE_Magic     : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#4D#, 16#5A#];                   --  'M' 'Z'
   Script_Magic : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#23#, 16#21#];                   --  '#' '!'
   PNG_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 8) :=
     [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];
                                         --  89 'P' 'N' 'G' CR LF 1A LF

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail
 is separate;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is separate;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail
 is separate;

   function Permission_String (Path : String) return String is separate;

   function Count_Text_Lines (Path : String) return Natural is separate;

   function Text_Encoding_Name (Path : String) return String is separate;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String is separate;

   function Pdf_Page_Count_Token (Path : String) return String is separate;

   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String
 is separate;

   --  True when the first Pattern'Length bytes read into Buffer (of which Last
   --  were read) equal Pattern. Buffer and Pattern are both 1-based.
   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean
 is separate;

   function Executable_Format_Token (Path : String) return String is separate;

   function Directory_Count_Token (Path : String) return String is separate;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is separate;

   function U32_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is separate;

   function Dimensions_Text
     (Width  : Natural;
      Height : Natural)
      return String is separate;

   function Image_Dimensions_Token
     (Path     : String;
      Filetype : String)
      return String
 is separate;

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind
 is separate;

   --  Build a fully-classified directory item for a single filesystem entry.
   --  Shared by directory loading and single-path stat so both populate size,
   --  timestamps, permissions, ownership, thumbnails, and filetype extras
   --  identically. Metadata failures are captured on the item rather than
   --  raised, matching the per-entry behaviour of directory loading.
   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
 is separate;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item
   is
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Type_Name : constant String :=
        (if Filetype /= "" then Filetype else Files.File_Types.Detect_Filetype (Settings, Kind, Name));
   begin
      return
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Join_Path (Parent_Path, Name)),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Type_Name),
         Icon_Id            => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Type_Name)),
         Size_Available     => False,
         Size               => 0,
         Creation_Available => False,
         Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Modified_Available => False,
         Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Permissions        => Null_Unbounded_String,
         Mode_Available     => False,
         Mode_Bits          => 0,
         Ownership_Available => False,
         Owner_Id           => 0,
         Group_Id           => 0,
         Filetype_Extra     => Null_Unbounded_String,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   end Make_Item;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
   begin
      return
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Join_Path (Parent_Path, Name)),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Filetype),
         Icon_Id            => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Filetype)),
         Size_Available     => False,
         Size               => 0,
         Creation_Available => False,
         Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Modified_Available => False,
         Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Permissions        => Null_Unbounded_String,
         Mode_Available     => False,
         Mode_Bits          => 0,
         Ownership_Available => False,
         Owner_Id           => 0,
         Group_Id           => 0,
         Filetype_Extra     => Null_Unbounded_String,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   end Make_Item;

   function Trash_Base_Path return String is separate;

   function Trash_Backend_For_Base return Trash_Backend is separate;

   function Path_Can_Be_Directory (Path : String) return Boolean is separate;

   function Two_Digit_Text (Value : Natural) return String is separate;

   function Move_To_Trash
     (Path         : String;
      Trashed_Path : out Files.Types.UString)
      return Mutation_Result
   is
      function Image_No_Space (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Image_No_Space;

      function Unique_Trash_Name
        (Files_Directory : String;
         Info_Directory  : String;
         Name            : String)
         return String
      is
         Counter   : Positive := 2;
         Candidate : Unbounded_String := To_Unbounded_String (Name);
      begin
         while Ada.Directories.Exists (Join_Path (Files_Directory, To_String (Candidate)))
           or else (Info_Directory /= ""
                    and then Ada.Directories.Exists
                               (Join_Path (Info_Directory, To_String (Candidate) & ".trashinfo")))
         loop
            Candidate := To_Unbounded_String (Name & "." & Image_No_Space (Counter));
            exit when Counter = Positive'Last;
            Counter := Counter + 1;
         end loop;

         return To_String (Candidate);
      end Unique_Trash_Name;

      function Trash_Info_Path_Value (Path_Value : String) return String is
         Hex    : constant String := "0123456789ABCDEF";
         Result : Unbounded_String;

         function Is_Unreserved (Value : Character) return Boolean is
         begin
            return (Value >= 'A' and then Value <= 'Z')
              or else (Value >= 'a' and then Value <= 'z')
              or else (Value >= '0' and then Value <= '9')
              or else Value = '-'
              or else Value = '.'
              or else Value = '_'
              or else Value = '~'
              or else Value = '/';
         end Is_Unreserved;
      begin
         for Value of Path_Value loop
            if Is_Unreserved (Value) then
               Append (Result, Value);
            else
               declare
                  Code : constant Natural := Character'Pos (Value);
               begin
                  Append (Result, '%');
                  Append (Result, Hex (Code / 16 + 1));
                  Append (Result, Hex (Code mod 16 + 1));
               end;
            end if;
         end loop;

         return To_String (Result);
      end Trash_Info_Path_Value;

      Backend    : constant Trash_Backend := Trash_Backend_For_Base;
      Macos_Home : constant Boolean := Backend = Trash_Macos_Home;
      Base       : constant String := Trash_Base_Path;
      --  macOS ~/.Trash stores items at the top level, without the freedesktop
      --  files/info split or .trashinfo sidecars, so Finder recognizes them.
      Files_Dir  : constant String :=
        (if Base = "" then ""
         elsif Macos_Home then Base
         else Join_Path (Base, "files"));
      Info_Dir   : constant String :=
        (if Base = "" or else Macos_Home then "" else Join_Path (Base, "info"));
      Name      : Unbounded_String;
      Target    : Unbounded_String;
      Info_Path : Unbounded_String;
      File      : Ada.Text_IO.File_Type;

      procedure Delete_Info_File_If_Present is
      begin
         if Ada.Directories.Exists (To_String (Info_Path)) then
            Ada.Directories.Delete_File (To_String (Info_Path));
         end if;
      exception
         when others =>
            null;
      end Delete_Info_File_If_Present;
   begin
      Trashed_Path := Null_Unbounded_String;
      declare
         Preflight : constant Mutation_Result := Move_To_Trash_Preflight (Path);
      begin
         if not Preflight.Success then
            return Preflight;
         end if;
      end;

      --  Hand the item to the desktop's own trash where the platform has one.
      --  These backends were written and then never called: everything went down
      --  the freedesktop path, so deleting on Windows built a .trashinfo sidecar
      --  in a directory the Recycle Bin knows nothing about.
      --
      --  The shell owns the item afterwards, so there is no path to hand back --
      --  which is also why an undo cannot restore it, and says so.
      if Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         declare
            Request : constant Native_Trash_Request :=
              (Backend                 => Backend,
               Path                    => To_Unbounded_String (Path),
               Requires_Native_Api     => True,
               Can_Use_Current_Process => True);

            Native : constant Native_Trash_Result :=
              (if Backend = Trash_Windows_Recycle_Bin
               then Files.Platform.Windows.Trash.Move (Request)
               else Files.Platform.Macos.Trash.Move (Request));
         begin
            if Native.Completed then
               return (Success => True, Error_Key => Null_Unbounded_String);
            end if;

            return
              (Success   => False,
               Error_Key =>
                 (if Native.Error_Key = Null_Unbounded_String
                  then To_Unbounded_String ("error.trash.failed")
                  else Native.Error_Key));
         end;
      end if;

      Ada.Directories.Create_Path (Files_Dir);
      if Info_Dir /= "" then
         Ada.Directories.Create_Path (Info_Dir);
      end if;

      Name := To_Unbounded_String
        (Unique_Trash_Name (Files_Dir, Info_Dir, Ada.Directories.Simple_Name (Path)));
      Target := To_Unbounded_String (Join_Path (Files_Dir, To_String (Name)));
      Trashed_Path := Target;

      if not Macos_Home then
         Info_Path := To_Unbounded_String (Join_Path (Info_Dir, To_String (Name) & ".trashinfo"));
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Info_Path));
         Ada.Text_IO.Put_Line (File, "[Trash Info]");
         Ada.Text_IO.Put_Line (File, "Path=" & Trash_Info_Path_Value (Ada.Directories.Full_Name (Path)));
         Ada.Text_IO.Put_Line (File, "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock));
         Ada.Text_IO.Close (File);
      end if;

      begin
         Ada.Directories.Rename (Path, To_String (Target));
      exception
         when others =>
            --  Cross-device (EXDEV): rename cannot move across filesystems, so
            --  the home trash is on a different mount than the file. Fall back
            --  to copy-then-delete into the trash.
            begin
               Copy_Tree (Path, To_String (Target));
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Path);
               begin
                  if not Removed.Success then
                     Delete_Info_File_If_Present;
                     return Removed;
                  end if;
               end;
            exception
               when others =>
                  Delete_Info_File_If_Present;
                  return
                    (Success   => False,
                     Error_Key => To_Unbounded_String ("error.trash.failed"));
            end;
      end;

      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         Delete_Info_File_If_Present;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Move_To_Trash;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
   is
      Ignored : Files.Types.UString;
   begin
      return Move_To_Trash (Path, Ignored);
   end Move_To_Trash;

   function Mutation_Leaf_Name (Path : String) return String is separate;

   --  Shared destination validation for the create-link commands: the new link
   --  path must be a valid, currently-unused leaf inside an existing directory.
   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result
 is separate;

   function Windows_Device_Basename (Name : String) return String is separate;

   function Is_Windows_Device_Name (Name : String) return Boolean is separate;

   function Is_All_Whitespace (Name : String) return Boolean is separate;

   function Ends_With_Whitespace (Name : String) return Boolean is separate;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
     is separate;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String
     is separate;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
     is separate;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
     is separate;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
     is separate;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
     is separate;

   --  The directory operations are subunits of Files.File_System.
   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result
     is separate;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
     is separate;

   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String
     is separate;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
     is separate;

   function Directory_State
     (Path : String)
      return Directory_Signature
     is separate;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
     is separate;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
     is separate;

   function Is_Directory (Item : Directory_Item) return Boolean is
   begin
      return Item.Kind = Files.Types.Directory_Item;
   end Is_Directory;

   --  The trash operations are subunits of Files.File_System.
   function Trash_Is_Available return Boolean
     is separate;

   function Trash_Backend_Of_Current_Environment return Trash_Backend
     is separate;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities
     is separate;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
     is separate;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     is separate;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     is separate;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
     is separate;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
     is separate;

   function Trash_Files_Directory return String
     is separate;

   function Restore_From_Trash
     (Trashed_Path : String)
      return Mutation_Result
     is separate;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
     is separate;

   --  The path operations are subunits of Files.File_System.
   function Normalize_Path
     (Path : String)
      return Path_Result
     is separate;

   function Parent_Directory
     (Path : String)
      return String
     is separate;

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String
     is separate;

   function Valid_Leaf_Name
     (Name : String)
      return Boolean
     is separate;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
     is separate;

   --  The search operations are subunits of Files.File_System.
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
     is separate;

   --  The roots operations are subunits of Files.File_System.
   function Available_Roots return Files.Types.String_Vectors.Vector
     is separate;

   function Available_Root_Entries return Root_Entry_Vectors.Vector
     is separate;

   function Root_Label (Path : String; Kind : Root_Kind) return String
     is separate;

   function Root_Discovery_Status return Root_Discovery_Diagnostics
     is separate;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities
     is separate;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile
     is separate;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
     is separate;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
     is separate;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy
     is separate;

   --  The create operations are subunits of Files.File_System.
   function Create_Empty_File
     (Path : String)
      return Mutation_Result
     is separate;

   function Create_Directory
     (Path : String)
      return Mutation_Result
     is separate;

   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result
     is separate;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     is separate;

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     is separate;

   --  The permissions operations are subunits of Files.File_System.
   function Supports_Permissions return Boolean
     is separate;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural
     is separate;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
     is separate;

   function Supports_Ownership return Boolean
     is separate;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean)
     is separate;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
     is separate;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     is separate;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     is separate;

   function User_Name_For_Id (Id : Natural) return String
     is separate;

   function Group_Name_For_Id (Id : Natural) return String
     is separate;

   --  The copy move operations are subunits of Files.File_System.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
      return Mutation_Result
     is separate;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
     is separate;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
     is separate;

   function Execute_Drop_Import
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result
     is separate;

end Files.File_System;
