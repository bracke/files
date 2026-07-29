with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Directories;
with Ada.Streams;
with GNAT.OS_Lib;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Files.File_Types;
with Files.Fs;
with Files.Platform.Metadata;
with Hostkit.Fs;
with Ada.Streams.Stream_IO;

package body Files.File_System.Directory is
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

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is
   begin
      return Natural (Value);
   end Stream_Byte;

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
      return Cached_Thumbnail;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail;

   function Permission_String (Path : String) return String;

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

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind;

   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
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
      return Boolean is
   begin
      return Is_Image_Item (Kind, Filetype, Name, Icon_Id);
   end Should_Auto_Generate_Thumbnail;

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

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
 is separate;

   function Permission_String (Path : String) return String is
      Result : String (1 .. 3) := "---";
   begin
      if GNAT.OS_Lib.Is_Owner_Readable_File (Path) then
         Result (1) := 'r';
      end if;
      if GNAT.OS_Lib.Is_Owner_Writable_File (Path) then
         Result (2) := 'w';
      end if;
      if Hostkit.Fs.Is_Executable (Path) then
         Result (3) := 'x';
      end if;

      return Result;
   exception
      when others =>
         return "";
   end Permission_String;

   function Count_Text_Lines (Path : String) return Natural is separate;

   function Text_Encoding_Name (Path : String) return String is separate;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String is
   begin
      return Prefix & ".lines_encoding|" & Natural_Text (Count_Text_Lines (Path)) & "|" & Text_Encoding_Name (Path);
   end Text_Metadata_Token;

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
   is
      use type Ada.Streams.Stream_Element_Array;
   begin
      return Last >= Pattern'Last and then Buffer (Pattern'Range) = Pattern;
   end Matches_Signature;

   function Executable_Format_Token (Path : String) return String is separate;

   function Directory_Count_Token (Path : String) return String is separate;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is
   begin
      return Stream_Byte (Buffer (Start)) * 256 + Stream_Byte (Buffer (Start + 1));
   end U16_BE;

   function U32_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is
   begin
      return
        Stream_Byte (Buffer (Start)) * 16#1000000#
        + Stream_Byte (Buffer (Start + 1)) * 16#10000#
        + Stream_Byte (Buffer (Start + 2)) * 16#100#
        + Stream_Byte (Buffer (Start + 3));
   end U32_BE;

   function Dimensions_Text
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      if Width = 0 or else Height = 0 then
         return "";
      end if;

      return Natural_Text (Width) & "x" & Natural_Text (Height);
   end Dimensions_Text;

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

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind
   is
      Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
   begin
      if Hostkit.Fs.Is_Link (Full) then
         return Files.Types.Symlink_Item;
      end if;

      case Ada.Directories.Kind (Dir_Entry) is
         when Ada.Directories.Directory =>
            return Files.Types.Directory_Item;
         when Ada.Directories.Ordinary_File =>
            if Hostkit.Fs.Is_Executable (Full) then
               return Files.Types.Executable_Item;
            end if;
            return Files.Types.Regular_File_Item;
         when Ada.Directories.Special_File =>
            return Files.Types.Other_Item;
      end case;
   exception
      when others =>
         return Files.Types.Unknown_Item;
   end Kind_From_Directory_Entry;

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

   function Directory_State
     (Path : String)
      return Directory_Signature
 is separate;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
   is
      After_State : constant Directory_Signature := Directory_State (Path);
      Changed     : constant Boolean :=
        Before_State.Exists /= After_State.Exists
        or else Before_State.Entry_Count /= After_State.Entry_Count
        or else Before_State.Entry_State_Checksum /= After_State.Entry_State_Checksum
        or else Before_State.Latest_Modified_Known /= After_State.Latest_Modified_Known
        or else
          (Before_State.Latest_Modified_Known
           and then After_State.Latest_Modified_Known
           and then Before_State.Latest_Modified /= After_State.Latest_Modified);
   begin
      return
        (Changed      => Changed,
         Before_State => Before_State,
         After_State  => After_State,
         Error_Key    =>
           (if After_State.Exists then Null_Unbounded_String else To_Unbounded_String ("error.directory.load")));
   end Detect_Directory_Change;

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

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
 is separate;

end Files.File_System.Directory;
