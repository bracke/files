with Files.Diagnostics;
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
with Files.Fs_Primitives;
with Files_Config;

with Hostkit.Metadata;
with Hostkit.Fs;
with Hostkit.Host;
with Files.UTF8;
with Files.File_System.Support;
with Files.File_System.Recovery;
with Files.File_Identities;
with Files.Private_Directories;
with Ada.Characters;
with Ada.Containers.Ordered_Sets;
with Ada.Unchecked_Deallocation;
with CryptoLib.Hashes;
with GNAT.CRC32;
with Files.Job_Context;
with Files.Io_Errors;
with Files.Platform;
with Hostkit.Trash;
with Files.Bounded_Text_IO;

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
   use type Files.Types.Sort_Field;
   use type Files.Types.Item_Kind;

   Max_Source_Side   : constant := 4096;

   Max_Source_Pixels : constant := 4_194_304;

   package Stream_IO renames Ada.Streams.Stream_IO;

   Max_Thumbnail_Dimension : constant Positive := 2_048;

   Max_Decode_Source_Bytes : constant Natural := 128 * 1024 * 1024;

   function Loader_New return System.Address
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_new";

   function Loader_Write
     (Loader : System.Address;
      Buffer : System.Address;
      Count  : Interfaces.C.size_t;
      Error  : System.Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_write";

   function Loader_Close
     (Loader : System.Address;
      Error  : System.Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_close";

   function Loader_Get_Pixbuf (Loader : System.Address) return System.Address
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_get_pixbuf";

   procedure Loader_Set_Size
     (Loader : System.Address; Width, Height : C_Int)
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_set_size";

   function Signal_Connect_Data
     (Instance        : System.Address;
      Detailed_Signal : Interfaces.C.Strings.chars_ptr;
      Handler         : System.Address;
      Data            : System.Address;
      Destroy_Data    : System.Address;
      Flags           : Interfaces.C.int) return Interfaces.C.unsigned_long
     with Import, Convention => C, External_Name => "g_signal_connect_data";

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

   package C_Int_Pointers is new System.Address_To_Access_Conversions (C_Int);

   use type C_Int_Pointers.Object_Pointer;

   procedure Loader_Size_Prepared
     (Loader : System.Address;
      Width, Height : C_Int;
      Data : System.Address)
     with Convention => C;

   procedure Loader_Size_Prepared
     (Loader : System.Address;
      Width, Height : C_Int;
      Data : System.Address)
   is separate;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   function Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural;

   function Thumbnail_Cache_Key
     (Source_Path : String)
      return String;

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

   function Thumbnail_Cache_Key
     (Source_Path : String)
      return String
   is separate;

   Cache_Byte_Budget : constant Long_Long_Integer := 64 * 1024 * 1024;

   Max_Cache_Prune_Entries : constant Natural := 100_000;

   package Cache_Path_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Unbounded_String);

   Max_Remembered_Cache_Paths : constant Natural := 256;

   protected Cache_Prune_Registry is
      procedure Claim (Path : String; Prune : out Boolean);
   private
      Seen : Cache_Path_Sets.Set;
   end Cache_Prune_Registry;

   protected body Cache_Prune_Registry is
      procedure Claim (Path : String; Prune : out Boolean) is
         Key : constant Unbounded_String := To_Unbounded_String (Path);
      begin
         if Seen.Contains (Key) then
            Prune := False;
         else
            Prune := True;
            --  Keep the registry itself bounded. Beyond the cap, pruning again
            --  is safer than retaining one attacker-controlled path forever.
            if Natural (Seen.Length) < Max_Remembered_Cache_Paths then
               Seen.Insert (Key);
            end if;
         end if;
      end Claim;
   end Cache_Prune_Registry;

   procedure Prune_Thumbnail_Cache
     (Cache_Directory : String;
      Budget_Bytes    : Long_Long_Integer)
   is separate;

   procedure Prune_Cache_Once (Cache_Directory : String) is separate;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is separate;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is separate;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is separate;

   function Read_Bounded_Regular_File
     (Path : String; Max_Bytes : Natural;
      Success, Complete : out Boolean) return String
   is separate;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      Success : Boolean;
   begin
      return Read_Preview_Text (Path, Max_Bytes, Success);
   end Read_Preview_Text;

   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success : out Boolean) return String
   is separate;

   function Image_Bytes_Extent
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
   is separate;

   function Decode_Image_Bytes
     (Data : Ada.Streams.Stream_Element_Array)
      return Decoded_Image
   is separate;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is separate;

   function Clamp_Channel (Value : Natural) return Natural is separate;

   function File_Size_Signal (Source_Path : String) return Natural is separate;

   Max_Fast_Decode_Source_Bytes : constant Natural := 33_554_432;

   function Source_Fits_Fast_Decode (Source_Path : String) return Boolean is separate;

   type Rgba_Pixel is record
      Red   : Natural := 0;
      Green : Natural := 0;
      Blue  : Natural := 0;
      Alpha : Natural := 255;
   end record;

   package Pixel_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Rgba_Pixel);

   package Thumbnail_Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Ada.Streams.Stream_Element);

   type Stream_Element_Array_Access is
     access Ada.Streams.Stream_Element_Array;

   procedure Free_Stream_Element_Array is new Ada.Unchecked_Deallocation
     (Object => Ada.Streams.Stream_Element_Array,
      Name   => Stream_Element_Array_Access);

   type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;

   pragma Convention (C, Gdk_Pixel_Array);

   package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);

   use type Gdk_Pixel_Pointers.Object_Pointer;

   function Byte_At
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural is separate;

   function U32_BE_From
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural
   is separate;

   function Bytes_To_Stream_Array
     (Data : Thumbnail_Byte_Vectors.Vector)
      return Stream_Element_Array_Access
   is separate;

   procedure Write_Pixels_As_Ppm
     (Target_Path   : String;
      Size          : Positive;
      Pixels        : Pixel_Vectors.Vector;
      Source_Width  : Natural;
      Source_Height : Natural)
   is separate;

   function Try_Write_Decoded_P3_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   function Try_Write_Decoded_Png_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   function Try_Write_Gdk_Pixbuf_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   Checksum  : Natural := 0;

   Size_Bias : Natural := 0;

   Target    : Unbounded_String;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
   is separate;

   use type Ada.Streams.Stream_Element_Array;

   use type Ada.Streams.Stream_IO.Count;

   use type GNAT.OS_Lib.File_Descriptor;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is separate;

   Extra_Line_Limit : constant Natural := 20_000;

   Extra_Scan_Byte_Limit : constant Long_Long_Integer := 8_388_608;

   Max_Directory_Count_Entries : constant Natural := 10_000;

   Max_Cached_Thumbnail_Bytes  : constant Natural := 16 * 1024 * 1024;

   Max_Legacy_Thumbnail_Bytes  : constant Natural := 1 * 1024 * 1024;

   Max_Cached_Thumbnail_Pixels : constant Natural := 2_048 * 2_048;

   Max_Thumbnail_Cache_Entries : constant Natural := 100_000;

   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   ELF_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 4) :=
     [16#7F#, 16#45#, 16#4C#, 16#46#];   --  7F 'E' 'L' 'F'

   PE_Magic     : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#4D#, 16#5A#];                   --  'M' 'Z'

   Script_Magic : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#23#, 16#21#];                   --  '#' '!'

   PNG_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 8) :=
     --  89 'P' 'N' 'G' CR LF 1A LF
     [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

   package Thumbnail_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   type Cache_Index is record
      Listed : Boolean := False;
      Names  : Thumbnail_Name_Sets.Set;
      --  False for a listing the UI waits on: a missing thumbnail is then
      --  left for a background listing to make.
      Generate : Boolean := True;
      --  True when Names is empty and the remembered listing answers
      --  instead (Cache_Index_Memo), so it is never copied per directory.
      Shared   : Boolean := False;
   end record;

   --  Whether the cache holds Name, by the index or the listing it shares.
   function Cache_Holds (Index : Cache_Index; Name : String) return Boolean;

   --  Read the cache directory once. A cache that does not exist yet yields an
   --  empty listing. An unreadable or oversized cache falls back to per-item
   --  checks rather than losing cached results or retaining unbounded names.
   function Index_Thumbnail_Cache (Cache_Directory : String) return Cache_Index;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String;
      Cached          : Cache_Index)
      return Cached_Thumbnail;

   --  @param Path The item's full path.
   --  @param Kind How the item was already classified, which for most kinds
   --              settles executability without asking the host again.
   --  @param Mode_Bits POSIX mode already read for this item, when Mode_Known.
   --  @param Mode_Known True when Mode_Bits are the host's own bits.
   function Permission_String
     (Path       : String;
      Kind       : Files.Types.Item_Kind;
      Mode_Bits  : Natural;
      Mode_Known : Boolean)
      return String;

   function Count_Text_Lines (Path : String) return Natural;

   function Text_Encoding_Name (Path : String) return String;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String;

   function Pdf_Page_Count_Token (Path : String) return String;

   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String;

   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean;

   function Executable_Format_Token (Path : String) return String;

   function Directory_Count_Token (Path : String) return String;

   --  The detail line's symlink entry. The "symlink.target|" prefix is this
   --  application's own token format, not a host fact, so it is written here
   --  over Hostkit's reader rather than asked of the host.
   function Symlink_Target_Token (Path : String) return String;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural;

   function U32_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural;

   function Dimensions_Text
     (Width  : Natural;
      Height : Natural)
      return String;

   function Image_Dimensions_Token
     (Path     : String;
      Filetype : String)
      return String;

   function Kind_From_Path
     (Full : String)
      return Files.Types.Item_Kind;

   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model;
      Cached      : Cache_Index)
      return Directory_Item;

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

   function List_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is separate;

   protected Cache_Index_Memo is
      function Holds (Directory : String; Stamp : Ada.Calendar.Time) return Boolean;
      function Contains (Name : String) return Boolean;
      procedure Keep (Directory : String; Stamp : Ada.Calendar.Time; Index : Cache_Index);
   private
      Kept_Directory : Unbounded_String;
      Kept_Stamp     : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      Kept_Index     : Cache_Index;
      Valid          : Boolean := False;
   end Cache_Index_Memo;

   protected body Cache_Index_Memo is
      function Holds (Directory : String; Stamp : Ada.Calendar.Time) return Boolean is
      begin
         return Valid and then To_String (Kept_Directory) = Directory and then Kept_Stamp = Stamp;
      end Holds;

      function Contains (Name : String) return Boolean is
        (Valid and then Kept_Index.Names.Contains (Name));

      procedure Keep (Directory : String; Stamp : Ada.Calendar.Time; Index : Cache_Index) is
      begin
         Kept_Directory := To_Unbounded_String (Directory);
         Kept_Stamp := Stamp;
         Kept_Index := Index;
         Valid := True;
      end Keep;
   end Cache_Index_Memo;

   function Index_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is separate;

   function Cache_Holds (Index : Cache_Index; Name : String) return Boolean is
     (if Index.Shared then Cache_Index_Memo.Contains (Name) else Index.Names.Contains (Name));

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String;
      Cached          : Cache_Index)
      return Cached_Thumbnail
   is separate;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Types.Sort_Field;
      Ascending : Boolean)
   is separate;

   function Permission_String
     (Path       : String;
      Kind       : Files.Types.Item_Kind;
      Mode_Bits  : Natural;
      Mode_Known : Boolean)
      return String
   is separate;

   procedure Close_Read_Descriptor
     (File : in out GNAT.OS_Lib.File_Descriptor)
   is separate;

   procedure Read_Descriptor
     (File   : GNAT.OS_Lib.File_Descriptor;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is separate;

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

   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean
   is separate;

   function Executable_Format_Token (Path : String) return String is separate;

   function Symlink_Target_Token (Path : String) return String is separate;

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

   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String is separate;

   function Kind_From_Path
     (Full : String)
      return Files.Types.Item_Kind
   is separate;

   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model;
      Cached      : Cache_Index)
      return Directory_Item
   is separate;

   --  The freedesktop trash per volume: an item on another device than the
   --  home trash goes to its volume's own trash ($topdir/.Trash/$uid when the
   --  administrator made a sticky .Trash there, else $topdir/.Trash-$uid), a
   --  rename instead of a copy into home. The trash view lists them all.

   --  Whether volume trashes are used: the freedesktop backends, on a host
   --  with numeric user ids.
   function Volume_Trash_Supported return Boolean;

   --  How many volume trashes the list of those trashed into keeps.
   Max_Remembered_Volume_Trashes : constant := 64;

   --  The volume trashes this application has trashed into, oldest first, as
   --  Volume_Trash_For recorded them (unvalidated).
   function Remembered_Volume_Trashes return Files.Types.String_Vectors.Vector;

   --  Whether Base is one of this user's volume trash directories: named
   --  .Trash-$uid, or $uid inside a sticky .Trash, a real directory (not a
   --  link) owned by this user.
   function Valid_Volume_Trash_Base (Base : String) return Boolean;

   --  Whether Parent may hold this user's volume trash: for the shared
   --  .Trash (Shared), a real directory owned by root with the sticky bit,
   --  so no one else can swap our folder in it for a link; for the volume's
   --  top, a real directory others cannot write to without the sticky bit.
   function Safe_Trash_Parent (Parent : String; Shared : Boolean) return Boolean;

   --  The top of the volume a volume trash Base belongs to: the parent of
   --  .Trash-$uid, or of .Trash for .Trash/$uid.
   function Volume_Trash_Top (Base : String) return String;

   --  The volume trash to move Path into, created if need be and remembered
   --  for the trash view; "" when Path is on the home trash's device or its
   --  volume has no usable trash (read-only, no permission), and the home
   --  trash is used.
   function Volume_Trash_For (Path : String) return String;

   --  Every existing volume trash of this user: on the mounts the root list
   --  shows, and those this application has trashed into.
   function Volume_Trash_Bases return Files.Types.String_Vectors.Vector;

   --  The trash directory (holding files/ and info/) whose files/ directly
   --  holds Trashed_Path: the home trash or a volume trash; "" for anything
   --  else.
   function Trash_Base_Of (Trashed_Path : String) return String;

   function Load_Directory_Filtered
     (Path     : String;
      Settings : Files.Settings.Settings_Model;
      Options  : Files.Types.Listing_Options;
      Include  : access function
        (Name : String; Kind : Files.Types.Item_Kind) return Boolean;
      Generate_Thumbnails : Boolean := False)
      return Directory_Load_Result
   is separate;

   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Load_Directory_Deferring_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Load_Directory_Generating_Thumbnails
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result is separate;

   function Thumbnails_Missing (Items : Item_Vectors.Vector) return Boolean is separate;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
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

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item
   is separate;

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
         Hidden             => Name'Length > 0 and then Name (Name'First) = '.',
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
         Filetype_Extra_Loaded => False,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Shared_Bytes.Empty,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   end Make_Item;

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

   function Original_Path (Trashed_Path : String) return String;

   function Restore_From_Trash_Backend
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result;

   function Delete_From_Trash_Backend
     (Trashed_Path : String)
      return Mutation_Result;

   function Trash_Base_Path return String;

   function Path_Can_Be_Directory (Path : String) return Boolean;

   function Two_Digit_Text (Value : Natural) return String;

   type Trash_Location is record
      Backend : Trash_Backend := Trash_Unavailable;
      Base    : Unbounded_String := Null_Unbounded_String;
   end record;

   function Trash_Location_For_Environment return Trash_Location is separate;

   function Trash_Base_Path return String is separate;

   function Trash_Files_Directory return String is separate;

   function Valid_Original_Path (Path : String) return Boolean is separate;

   function Is_Trash_Payload (Path, Payload_Directory : String) return Boolean is separate;

   function Volume_Trash_Supported return Boolean is separate;

   function Remembered_Volume_Trashes return Files.Types.String_Vectors.Vector is separate;

   function Valid_Volume_Trash_Base (Base : String) return Boolean is separate;

   function Safe_Trash_Parent (Parent : String; Shared : Boolean) return Boolean is separate;

   function Volume_Trash_Top (Base : String) return String is
     (if Ada.Directories.Simple_Name (Base) (1 .. Natural'Min (7, Ada.Directories.Simple_Name (Base)'Length))
           = ".Trash-"
      then Ada.Directories.Containing_Directory (Base)
      else Ada.Directories.Containing_Directory (Ada.Directories.Containing_Directory (Base)));

   function Volume_Trash_For (Path : String) return String is separate;

   function Volume_Trash_Bases return Files.Types.String_Vectors.Vector is separate;

   function Trash_Base_Of (Trashed_Path : String) return String is separate;

   function Is_User_Visible_Mount_Point (Mount_Point : String; Runtime_Gvfs : String) return Boolean is separate;

   function Is_Volume_Trash_Item (Path : String) return Boolean is
      Base : constant String := Trash_Base_Of (Path);
   begin
      return Base /= "" and then Base /= Trash_Base_Path;
   end Is_Volume_Trash_Item;

   function Path_Can_Be_Directory (Path : String) return Boolean is separate;

   function Two_Digit_Text (Value : Natural) return String is separate;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
   is separate;

   function Trash_Is_Available return Boolean is separate;

   function Trash_Backend_Of_Current_Environment return Trash_Backend is separate;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities is separate;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result is separate;

   function Trash_Natively
     (Request : Native_Trash_Request)
      return Native_Trash_Result is separate;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
   is separate;

   function Move_To_Trash
     (Path          : String;
      Trashed_Path  : out Files.Types.UString;
      Recorded_Path : String := "")
      return Mutation_Result
   is separate;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
   is
      Ignored : Files.Types.UString;
   begin
      return Move_To_Trash (Path, Ignored);
   end Move_To_Trash;

   function Delete_From_Trash_Backend
     (Trashed_Path : String)
      return Mutation_Result
   is separate;

   function Original_Path (Trashed_Path : String) return String is separate;

   function Restore_From_Trash_Backend
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result
   is separate;

   function Is_Trash_Files_Directory (Path : String) return Boolean is
      Trash_Dir : constant String := Trash_Files_Directory;
   begin
      return Path /= ""
        and then Trash_Dir /= ""
        and then
          (Path = Trash_Dir
           or else Hostkit.Metadata.Same_File (Path, Trash_Dir));
   exception
      when others =>
         return False;
   end Is_Trash_Files_Directory;

   function Trash_Original_Path (Trashed_Path : String) return String is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Original_Path (Trashed_Path);
      end if;
      return Original_Path (Trashed_Path);
   end Trash_Original_Path;

   function Is_Recovery_Payload (Path : String) return Boolean
     renames Recovery.Recognizes;

   function Release_Recovery_Payload (Path : String) return Mutation_Result is
      function To_Trash (Entry_Path, Original : String) return Mutation_Result is
         Ignored : Files.Types.UString;
      begin
         return Move_To_Trash (Entry_Path, Ignored, Recorded_Path => Original);
      end To_Trash;
   begin
      return Recovery.Release (Path, To_Trash'Access);
   end Release_Recovery_Payload;

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
      return Restore_From_Trash_Backend (Trashed_Path, Expected_Identity, Expected_Original);
   end Restore_From_Trash;

   function Preserve_For_Replace
     (Path : String; Recovery_Path : out Files.Types.UString) return Mutation_Result
   is
      Result : Mutation_Result;
   begin
      Recovery_Path := Null_Unbounded_String;
      --  Replacement must remain reversible.  Refuse before moving the
      --  original when this host cannot identify it, rather than publishing a
      --  new destination whose retained original cannot be safely restored.
      if Files.File_Identities.Token (Path) = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      if Trash_Backend_Of_Current_Environment in Trash_Xdg_Data_Home | Trash_Home_Data then
         Result := Move_To_Trash (Path, Recovery_Path);
      else
         Result := Recovery.Preserve (Path, Recovery_Path);
      end if;

      if Result.Success
        and then
          (Length (Recovery_Path) = 0
           or else Files.File_Identities.Token (To_String (Recovery_Path)) = "")
      then
         if Length (Recovery_Path) > 0 then
            declare
               Restored : constant Mutation_Result :=
                 Restore_From_Trash
                   (To_String (Recovery_Path), Expected_Original => Path);
            begin
               if Restored.Success then
                  Recovery_Path := Null_Unbounded_String;
               end if;
            end;
         end if;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;
      return Result;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Preserve_For_Replace;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
   begin
      if Recovery.Recognizes (Trashed_Path) then
         return Recovery.Discard (Trashed_Path);
      end if;
      return Delete_From_Trash_Backend (Trashed_Path);
   end Delete_Trashed_Item;

   use type Hostkit.Host.Kind;

   function Parent_Directory (Path : String) return String is separate;

   function Expand_User_Path (Path : String) return String is separate;

   function Normalize_Path
     (Path : String)
      return Path_Result
   is separate;

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String is separate;

   function Windows_Device_Basename (Name : String) return String is separate;

   function Is_Windows_Device_Name (Name : String) return Boolean is separate;

   function Is_All_Whitespace (Name : String) return Boolean is separate;

   function Ends_With_Whitespace (Name : String) return Boolean is separate;

   function Valid_Leaf_Name
     (Name  : String;
      Rules : Name_Rules := Host_Rules)
      return Boolean
   is separate;

   function Valid_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
   is
     (Valid_Leaf_Name
        (Name,
         (if Hostkit.Fs.Uses_Dos_Filename_Rules (Directory)
          then Windows_Rules
          else Posix_Rules)));

   function Storable_Leaf_Name_At
     (Name      : String;
      Directory : String)
      return Boolean
   is separate;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
   is separate;

   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
   is separate;

   Max_Mount_Record_Length : constant Positive := 64 * 1024;

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
      Info : out Volume_Size_Info);

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String;

   function Simple_Device_Name (Source : String) return String;

   function Parent_Block_Device_Name (Device : String) return String;

   function Read_First_Line (Path : String) return String;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata;

   function Root_Label (Path : String; Kind : Root_Kind) return String is separate;

   function Available_Root_Entries return Root_Entry_Vectors.Vector is separate;

   function Available_Roots return Files.Types.String_Vectors.Vector is separate;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is separate;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities is separate;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile is separate;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
   is separate;

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

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
   is separate;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy is separate;

   function Mutation_Leaf_Name (Path : String) return String;

   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result;

   function Mutation_Leaf_Name (Path : String) return String is separate;

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
      To_Path   : String;
      Expected_Identity : String := "")
      return Mutation_Result
   is separate;

   function Validate_Link_Destination
     (Link_Path : String)
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

   package Id_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Files.Types.Account_Id,
      Element_Type => Unbounded_String,
      "<"          => Hostkit.Metadata."<");

   User_Name_Cache  : Id_Name_Maps.Map;

   Group_Name_Cache : Id_Name_Maps.Map;

   function Supports_Permissions return Boolean is separate;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is separate;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
   is separate;

   function Supports_Ownership return Boolean is separate;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Files.Types.Account_Id;
      Group_Id  : out Files.Types.Account_Id;
      Available : out Boolean) is separate;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Files.Types.Account_Id is separate;

   function User_Name_For_Id (Id : Files.Types.Account_Id) return String is separate;

   function Group_Name_For_Id (Id : Files.Types.Account_Id) return String is separate;

   subtype Update_Field is Hostkit.Metadata.Identity_Field;

   --  The one mutation behind Change_Mode and Change_Ownership: verify the
   --  recorded identity (when there is one), update through the held entry,
   --  and report the value it had and the identity actually changed. A
   --  previous value above Max_Previous is refused rather than truncated.
   function Update_Verified_Entry
     (Path, Expected_Identity : String; Kind : Hostkit.Metadata.Metadata_Update_Kind;
      Value, Group, Max_Previous : Update_Field; Owner_Name, Group_Name : String;
      Previous, Previous_Group : out Update_Field; Identity : out Files.Types.UString) return Boolean
   is
      subtype U64 is Update_Field;
      use type U64;
      Expected : Hostkit.Metadata.Entry_Identity;
      Updated  : Hostkit.Metadata.Metadata_Update_Result;

      function Parse_Identity
        (Text : String; Item : out Hostkit.Metadata.Entry_Identity) return Boolean
      is
         Position : Natural := Text'First;
         Values   : array (1 .. 4) of U64 := [others => 0];
      begin
         Item := (others => <>);
         for Index in Values'Range loop
            while Position <= Text'Last and then Text (Position) = ' ' loop
               Position := Position + 1;
            end loop;
            if Position > Text'Last or else Text (Position) not in '0' .. '9' then
               return False;
            end if;
            declare
               First : constant Natural := Position;
            begin
               while Position <= Text'Last and then Text (Position) in '0' .. '9' loop
                  Position := Position + 1;
               end loop;
               Values (Index) := U64'Value (Text (First .. Position - 1));
            end;
         end loop;
         while Position <= Text'Last and then Text (Position) = ' ' loop
            Position := Position + 1;
         end loop;
         if Position <= Text'Last then
            return False;
         end if;
         Item :=
           (Available       => True,
            Volume          => Values (1),
            File_Number     => Values (2),
            Generation_High => Values (3),
            Generation_Low  => Values (4));
         return True;
      exception
         when others =>
            Item := (others => <>);
            return False;
      end Parse_Identity;
   begin
      Previous := 0;
      Previous_Group := 0;
      Identity := Null_Unbounded_String;
      if Expected_Identity /= ""
        and then not Parse_Identity (Expected_Identity, Expected)
      then
         return False;
      end if;
      Updated := Hostkit.Metadata.Update_Entry_Metadata
        (Path           => Path,
         Expected       => Expected,
         Check_Expected => Expected_Identity /= "",
         Kind           => Kind,
         Value          => Value,
         Group          => Group,
         Max_Previous   => Max_Previous,
         Owner_Name     => Owner_Name,
         Group_Name     => Group_Name);
      if not Updated.Success
        or else Updated.Previous > Max_Previous
        or else Updated.Previous_Group > Max_Previous
      then
         return False;
      end if;
      Previous := Updated.Previous;
      Previous_Group := Updated.Previous_Group;
      Identity := To_Unbounded_String
        (U64'Image (Updated.Identity.Volume)
         & U64'Image (Updated.Identity.File_Number)
         & U64'Image (Updated.Identity.Generation_High)
         & U64'Image (Updated.Identity.Generation_Low));
      return True;
   exception
      when others => return False;
   end Update_Verified_Entry;

   function Change_Mode
     (Path, Expected_Identity : String; Mode : Natural;
      Previous : out Natural; Identity : out Files.Types.UString) return Mutation_Result
   is
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.permissions.failed"));
      Old_Mode, Unused_Group : Update_Field;
   begin
      Previous := 0;
      Identity := Null_Unbounded_String;
      if Mode > 8#7777# then
         return Failed;
      end if;
      if not Update_Verified_Entry
        (Path, Expected_Identity, Hostkit.Metadata.Update_Permissions,
         Value => Update_Field (Mode), Group => 0, Max_Previous => Update_Field (Natural'Last),
         Owner_Name => "", Group_Name => "",
         Previous => Old_Mode, Previous_Group => Unused_Group, Identity => Identity)
      then
         return Failed;
      end if;
      Previous := Natural (Old_Mode);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others => return Failed;
   end Change_Mode;

   function Change_Ownership
     (Path, Expected_Identity : String; User_Id, Group_Id : Files.Types.Account_Id;
      Previous_User, Previous_Group : out Files.Types.Account_Id; Identity : out Files.Types.UString;
      Owner_Name : String := ""; Group_Name : String := "") return Mutation_Result
   is
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.ownership.denied"));
      Old_User, Old_Group : Update_Field;
   begin
      Previous_User := 0;
      Previous_Group := 0;
      Identity := Null_Unbounded_String;
      if not Update_Verified_Entry
        (Path, Expected_Identity, Hostkit.Metadata.Update_Ownership,
         Value => Update_Field (User_Id), Group => Update_Field (Group_Id),
         Max_Previous => Update_Field (Files.Types.Account_Id'Last),
         Owner_Name => (if Owner_Name /= "" then Owner_Name else User_Name_For_Id (User_Id)),
         Group_Name => (if Group_Name /= "" then Group_Name else Group_Name_For_Id (Group_Id)),
         Previous => Old_User, Previous_Group => Old_Group, Identity => Identity)
      then
         return Failed;
      end if;
      Previous_User := Files.Types.Account_Id (Old_User);
      Previous_Group := Files.Types.Account_Id (Old_Group);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others => return Failed;
   end Change_Ownership;

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result is
   begin
      Files.Io_Errors.Reset;
      Support.Copy_To_New_Path (Source_Path, Destination_Path, Batch => Batch);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => Files.Io_Errors.Error_Key ("error.copy.failed"));
   end Copy_Tree;

   function Copy_Tree
     (Source_Path, Destination_Path : String;
      Identity, Tree_Revision_Value : out Files.Types.UString;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result is separate;

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
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
   is
      Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
   begin
      return Execute_Drop_Import (Plans, Identities, Tree_Revisions, Cancel, Batch);
   end Execute_Drop_Import;

   function Execute_Drop_Import
     (Plans  : Drop_Import_Plan_Vectors.Vector;
      Created_Identities, Created_Tree_Revisions : out Files.Types.String_Vectors.Vector;
      Cancel : Cancellation_Check := null;
      Batch : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
      return Mutation_Result
   is separate;

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
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
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
         Stage : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Removed : constant Mutation_Result := Delete_Permanently (Stage);
         pragma Unreferenced (Removed);
      begin
         --  Preserve registered the backup; once its stage is gone the record
         --  would otherwise leak and slowly exhaust the registry.
         if not Ada.Directories.Exists (Stage) and then not Hostkit.Fs.Is_Link (Stage) then
            Recovery.Unregister (To_String (Backup));
         end if;
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

   function Entry_Identity_Matches (Path, Expected : String) return Boolean is
   begin
      return Expected /= ""
        and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path))
        and then Files.File_Identities.Token (Path) = Expected;
   exception
      when others =>
         return False;
   end Entry_Identity_Matches;

   function Creation_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean is
   begin
      if not Entry_Identity_Matches (Path, Identity) then
         return Retain_Verified and then Identity /= "";
      end if;
      return
        (if Hostkit.Fs.Is_Link (Path) then Tree_Revision = ""
         else Tree_Revision /= "" and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when others =>
         return False;
   end Creation_Matches;

end Files.File_System;
