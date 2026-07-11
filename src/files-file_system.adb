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
with Files.Platform.Windows;
with Files.UTF8;

package body Files.File_System is
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

   --  Session cache for numeric-id -> name resolution. Build_Snapshot resolves
   --  the selected items' owner/group names every frame, so memoize each id's
   --  name (including an unresolved "") to avoid repeated getpwuid/getgrgid.
   package Id_Name_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Natural,
      Element_Type => Unbounded_String);
   User_Name_Cache  : Id_Name_Maps.Map;
   Group_Name_Cache : Id_Name_Maps.Map;
   use type System.Address;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;

   subtype C_Int is Interfaces.C.int;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;
   subtype C_Size is Interfaces.C.size_t;
   subtype C_ULong is Interfaces.C.unsigned_long;

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

   subtype C_Char is Interfaces.C.char;

   Extra_Line_Limit : constant Natural := 20_000;

   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean);

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type);

   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type);

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   function Safe_Environment_Value
     (Name : String)
      return String;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean;

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

   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean) is
   begin
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
         Started := False;
      end if;
   end Safe_End_Search;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         begin
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is
   begin
      if Pointer /= Interfaces.C.Strings.Null_Ptr then
         begin
            Interfaces.C.Strings.Free (Pointer);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Free;

   function Safe_Environment_Value
     (Name : String)
      return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Types.To_Lower (Safe_Environment_Value (Name)) = Expected;
   end Environment_Equals;

   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   function Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Name : constant String := Ada.Directories.Simple_Name (Source_Path);
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' and then Index < Name'Last then
            return Files.Types.To_Lower (Name (Index + 1 .. Name'Last));
         end if;
      end loop;

      return "file";
   exception
      when others =>
         return "file";
   end Thumbnail_Extension;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Extension : constant String := Thumbnail_Extension (Source_Path);
      Result    : Unbounded_String;
   begin
      for Value of Extension loop
         if Ada.Characters.Handling.Is_Alphanumeric (Value) then
            Append (Result, Value);
         else
            Append (Result, '_');
         end if;
      end loop;

      if Length (Result) = 0 then
         return "file";
      end if;

      return To_String (Result);
   end Sanitized_Thumbnail_Extension;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Result  : Long_Long_Integer := 0;
   begin
      for Value of Source_Path loop
         Result := (Result * 33 + Long_Long_Integer (Character'Pos (Value))) mod Modulus;
      end loop;

      return Natural (Result);
   end Thumbnail_Path_Checksum;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is
      Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
      Home      : constant String := Safe_Environment_Value ("HOME");
   begin
      if Xdg_Cache /= "" then
         return Join_Path (Join_Path (Xdg_Cache, "files"), "thumbnails");
      elsif Home /= "" then
         return Join_Path (Join_Path (Join_Path (Home, ".cache"), "files"), "thumbnails");
      else
         return Join_Path (Fallback_Directory, ".files-thumbnails");
      end if;
   end Default_Thumbnail_Cache_Directory;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is
   begin
      return
        Join_Path
          (Cache_Directory,
           "thumb_"
           & Sanitized_Thumbnail_Extension (Source_Path)
           & "_"
           & Image_No_Space (Size)
           & "_"
           & Image_No_Space (Thumbnail_Path_Checksum (Source_Path))
           & ".ppm");
   end Thumbnail_Path_For;

   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail
   is
      Content : Unbounded_String;
      Token   : Unbounded_String;
      Cursor  : Positive := 1;
      Result  : Cached_Thumbnail;

      procedure Flush_Token
        (Tokens : in out Files.Types.String_Vectors.Vector)
      is
      begin
         if Length (Token) > 0 then
            Tokens.Append (Token);
            Token := Null_Unbounded_String;
         end if;
      end Flush_Token;

      function Tokens return Files.Types.String_Vectors.Vector is
         Values     : Files.Types.String_Vectors.Vector;
         In_Comment : Boolean := False;
      begin
         for Value of To_String (Content) loop
            if In_Comment then
               if Value = ASCII.LF or else Value = ASCII.CR then
                  In_Comment := False;
               end if;
            elsif Value = '#' then
               Flush_Token (Values);
               In_Comment := True;
            elsif Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
               Flush_Token (Values);
            else
               Append (Token, Value);
            end if;
         end loop;

         Flush_Token (Values);
         return Values;
      end Tokens;

      function Natural_Value
        (Text : String;
         Value : out Natural)
         return Boolean
      is
      begin
         Value := 0;
         if Text = "" then
            return False;
         end if;

         for Character_Value of Text loop
            if Character_Value not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Character_Value) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Character_Value) - Character'Pos ('0');
         end loop;

         return True;
      end Natural_Value;

      function Channel
        (Value     : Natural;
         Max_Value : Natural)
         return Interfaces.Unsigned_8 is
      begin
         if Max_Value = 0 then
            return 0;
         elsif Max_Value = 255 then
            return Interfaces.Unsigned_8 (Natural'Min (Value, 255));
         else
            return Interfaces.Unsigned_8 (Natural'Min ((Value * 255) / Max_Value, 255));
         end if;
      end Channel;
   begin
      if Path = ""
        or else not Files.Fs.File_Exists (Path)
      then
         return Result;
      end if;

      Content := Files.Fs.Read_Text_File (Path);

      declare
         Values    : constant Files.Types.String_Vectors.Vector := Tokens;
         Width     : Natural;
         Height    : Natural;
         Max_Value : Natural;
      begin
         if Natural (Values.Length) < 4
           or else To_String (Values.Element (1)) /= "P3"
           or else not Natural_Value (To_String (Values.Element (2)), Width)
           or else not Natural_Value (To_String (Values.Element (3)), Height)
           or else not Natural_Value (To_String (Values.Element (4)), Max_Value)
           or else Width = 0
           or else Height = 0
           or else Max_Value = 0
           or else Natural (Values.Length) < 4 + Width * Height * 3
         then
            return Result;
         end if;

         Cursor := 5;
         for Pixel in 1 .. Width * Height loop
            declare
               R : Natural;
               G : Natural;
               B : Natural;
            begin
               if not Natural_Value (To_String (Values.Element (Cursor)), R)
                 or else not Natural_Value (To_String (Values.Element (Cursor + 1)), G)
                 or else not Natural_Value (To_String (Values.Element (Cursor + 2)), B)
               then
                  return Result;
               end if;

               Result.Pixels.Append (Channel (R, Max_Value));
               Result.Pixels.Append (Channel (G, Max_Value));
               Result.Pixels.Append (Channel (B, Max_Value));
               Result.Pixels.Append (255);
               Cursor := Cursor + 3;
            end;
         end loop;

         Result.Loaded := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   exception
      when others =>
         return (Loaded => False, Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Load_Cached_Thumbnail;

   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is
      Extension : constant String := Files.File_Types.Extension_Of (Name);
   begin
      if Kind = Files.Types.Directory_Item
        or else Kind = Files.Types.Symlink_Item
      then
         return False;
      end if;

      return Starts_With (Files.Types.To_Lower (Filetype), "image/")
        or else Files.Types.To_Lower (Icon_Id) = "image"
        or else Extension = "png"
        or else Extension = "jpg"
        or else Extension = "jpeg"
        or else Extension = "gif"
        or else Extension = "bmp"
        or else Extension = "webp"
        or else Extension = "tif"
        or else Extension = "tiff"
        or else Extension = "ppm";
   end Is_Image_Item;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is
   begin
      return Is_Image_Item (Kind, Filetype, Name, Icon_Id);
   end Should_Auto_Generate_Thumbnail;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Total  : Natural := 0;
   begin
      if Max_Bytes = 0 then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Total < Max_Bytes loop
         Stream_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            exit when Total >= Max_Bytes;
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Natural (Buffer (Index))));
            Total := Total + 1;
         end loop;
      end loop;

      Stream_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         Safe_Close (File);
         return Ada.Strings.Unbounded.To_String (Result);
   end Read_Preview_Text;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail
   is
      Loaded : Cached_Thumbnail := Load_Cached_Thumbnail (Thumbnail_Path);
   begin
      if Loaded.Loaded
        or else not Should_Auto_Generate_Thumbnail (Kind, Filetype, Name, Icon_Id)
      then
         return Loaded;
      end if;

      declare
         Generated : constant Thumbnail_Result :=
           Generate_Thumbnail (Full_Path, Cache_Directory);
      begin
         if Generated.Status = Thumbnail_Generated then
            Loaded := Load_Cached_Thumbnail (To_String (Generated.Thumbnail_Path));
         end if;
      end;

      return Loaded;
   exception
      when others =>
         return Loaded;
   end Thumbnail_For_Item;

   type U64_Array is array (Positive range <>) of C_U64
     with Convention => C;

   function Is_Directory (Item : Directory_Item) return Boolean is
   begin
      return Item.Kind = Files.Types.Directory_Item;
   end Is_Directory;

   function Trash_Base_Path return String is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return "";
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return "";
      end if;

      if Xdg_Data_Home /= "" then
         return Join_Path (Xdg_Data_Home, "Trash");
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Join_Path (Home, ".Trash");
         end if;

         return Join_Path (Join_Path (Join_Path (Home, ".local"), "share"), "Trash");
      end if;

      return "";
   end Trash_Base_Path;

   function Trash_Backend_For_Base return Trash_Backend is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return Trash_Windows_Recycle_Bin;
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return Trash_Macos_Native;
      elsif Files_Config.Alire_Host_OS = "windows" then
         --  Windows has no HOME/XDG trash; use the shell Recycle Bin by default.
         return Trash_Windows_Recycle_Bin;
      elsif Xdg_Data_Home /= "" then
         return Trash_Xdg_Data_Home;
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Trash_Macos_Home;
         else
            return Trash_Home_Data;
         end if;
      end if;

      return Trash_Unavailable;
   end Trash_Backend_For_Base;

   function Trash_Files_Directory return String is
      Base    : constant String := Trash_Base_Path;
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
   begin
      if Base = "" then
         return "";
      end if;

      case Backend is
         when Trash_Macos_Home =>
            return Base;
         when Trash_Xdg_Data_Home | Trash_Home_Data =>
            return Join_Path (Base, "files");
         when others =>
            return "";
      end case;
   exception
      when others =>
         return "";
   end Trash_Files_Directory;

   function Path_Can_Be_Directory (Path : String) return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Path);
      Parent  : Unbounded_String;
   begin
      if Path = "" then
         return False;
      end if;

      loop
         declare
            Value : constant String := To_String (Current);
         begin
            if Value = "" then
               return False;
            elsif Ada.Directories.Exists (Value) then
               return Ada.Directories.Kind (Value) = Ada.Directories.Directory;
            end if;

            Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (Value));
            if To_String (Parent) = Value then
               return False;
            end if;
            Current := Parent;
         end;
      end loop;
   exception
      when others =>
         return False;
   end Path_Can_Be_Directory;

   function Parent_Directory (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      declare
         --  Containing_Directory resolves the parent cross-platform, trimming
         --  the final path component and handling trailing separators. It
         --  raises Use_Error at a filesystem root, where no parent exists.
         Parent : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Parent = "" or else Parent = Path then
            return "";
         end if;

         return Parent;
      end;
   exception
      when others =>
         return "";
   end Parent_Directory;

   function Name_Less (Left : Directory_Item; Right : Directory_Item) return Boolean is
      Left_Name       : constant String := To_String (Left.Name);
      Right_Name      : constant String := To_String (Right.Name);
      Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Name);
      Right_Lowercase : constant String := Files.Types.To_Lower (Right_Name);
   begin
      if Left_Lowercase /= Right_Lowercase then
         return Left_Lowercase < Right_Lowercase;
      else
         return Left_Name < Right_Name;
      end if;
   end Name_Less;

   function Text_Less (Left : UString; Right : UString) return Boolean is
      Left_Text       : constant String := To_String (Left);
      Right_Text      : constant String := To_String (Right);
      Left_Lowercase  : constant String := Files.Types.To_Lower (Left_Text);
      Right_Lowercase : constant String := Files.Types.To_Lower (Right_Text);
   begin
      if Left_Lowercase /= Right_Lowercase then
         return Left_Lowercase < Right_Lowercase;
      else
         return Left_Text < Right_Text;
      end if;
   end Text_Less;

   function Field_Less
     (Left      : Directory_Item;
      Right     : Directory_Item;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
      return Boolean
   is
      Forward_Order : Boolean := False;
      Reverse_Order : Boolean := False;
   begin
      case Field is
         when Files.Settings.Sort_By_Name =>
            Forward_Order := Name_Less (Left => Left, Right => Right);
            Reverse_Order := Name_Less (Left => Right, Right => Left);
         when Files.Settings.Sort_By_Filetype =>
            Forward_Order := Text_Less (Left => Left.Filetype, Right => Right.Filetype);
            Reverse_Order := Text_Less (Left => Right.Filetype, Right => Left.Filetype);
         when Files.Settings.Sort_By_Size =>
            if Left.Size_Available /= Right.Size_Available then
               return Left.Size_Available;
            elsif Left.Size /= Right.Size then
               Forward_Order := Left.Size < Right.Size;
               Reverse_Order := Right.Size < Left.Size;
            end if;
         when Files.Settings.Sort_By_Created =>
            if Left.Creation_Available /= Right.Creation_Available then
               return Left.Creation_Available;
            elsif Left.Creation_Time /= Right.Creation_Time then
               Forward_Order := Left.Creation_Time < Right.Creation_Time;
               Reverse_Order := Right.Creation_Time < Left.Creation_Time;
            end if;
         when Files.Settings.Sort_By_Modified =>
            if Left.Modified_Available /= Right.Modified_Available then
               return Left.Modified_Available;
            elsif Left.Modified_Time /= Right.Modified_Time then
               Forward_Order := Left.Modified_Time < Right.Modified_Time;
               Reverse_Order := Right.Modified_Time < Left.Modified_Time;
            end if;
      end case;

      if Field /= Files.Settings.Sort_By_Name
        and then not Forward_Order
        and then not Reverse_Order
      then
         return Name_Less (Left, Right);
      elsif Ascending then
         return Forward_Order;
      else
         return Reverse_Order;
      end if;
   end Field_Less;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
   is
      function Less (Left : Directory_Item; Right : Directory_Item) return Boolean is
      begin
         return Field_Less (Left, Right, Field, Ascending);
      end Less;

      package Sorting is new Item_Vectors.Generic_Sorting ("<" => Less);
   begin
      Sorting.Sort (Items);
   end Sort_Items;

   function Permission_String (Path : String) return String is
      Result : String (1 .. 3) := "---";
   begin
      if GNAT.OS_Lib.Is_Owner_Readable_File (Path) then
         Result (1) := 'r';
      end if;
      if GNAT.OS_Lib.Is_Owner_Writable_File (Path) then
         Result (2) := 'w';
      end if;
      if GNAT.OS_Lib.Is_Executable_File (Path) then
         Result (3) := 'x';
      end if;

      return Result;
   exception
      when others =>
         return "";
   end Permission_String;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Natural_Text;

   function Two_Digit_Text (Value : Natural) return String is
      Clean : constant String := Natural_Text (Value);
   begin
      if Value < 10 then
         return "0" & Clean;
      end if;

      return Clean;
   end Two_Digit_Text;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
   is
      Year      : Ada.Calendar.Year_Number;
      Month     : Ada.Calendar.Month_Number;
      Day       : Ada.Calendar.Day_Number;
      Seconds   : Ada.Calendar.Day_Duration;
      Remaining : Ada.Calendar.Day_Duration;
      Hour      : Natural := 0;
      Minute    : Natural := 0;
      Second    : Natural := 0;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Remaining := Seconds;

      while Remaining >= 3_600.0 loop
         Hour := Hour + 1;
         Remaining := Remaining - 3_600.0;
      end loop;

      while Remaining >= 60.0 loop
         Minute := Minute + 1;
         Remaining := Remaining - 60.0;
      end loop;

      while Remaining >= 1.0 loop
         Second := Second + 1;
         Remaining := Remaining - 1.0;
      end loop;

      return
        Natural_Text (Natural (Year)) & "-"
        & Two_Digit_Text (Natural (Month)) & "-"
        & Two_Digit_Text (Natural (Day)) & "T"
        & Two_Digit_Text (Hour) & ":"
        & Two_Digit_Text (Minute) & ":"
        & Two_Digit_Text (Second);
   end Trash_Deletion_Date;

   function Count_Text_Lines (Path : String) return Natural is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File        : Stream_IO.File_Type;
      Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last        : Ada.Streams.Stream_Element_Offset;
      Count       : Natural := 0;
      Saw_Byte    : Boolean := False;
      Last_Was_LF : Boolean := False;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Count < Extra_Line_Limit loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Saw_Byte := True;
               Last_Was_LF := Buffer (Index) = Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
               if Last_Was_LF then
                  Count := Count + 1;
                  exit when Count >= Extra_Line_Limit;
               end if;
            end loop;
         end if;
      end loop;

      if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then
         Count := Count + 1;
      end if;

      Stream_IO.Close (File);
      return Count;
   exception
      when others =>
         Safe_Close (File);
         return 0;
   end Count_Text_Lines;

   function Text_Encoding_Name (Path : String) return String is
      File       : Ada.Streams.Stream_IO.File_Type;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last       : Ada.Streams.Stream_Element_Offset;
      Byte_Value : Natural;
      Ascii_Only : Boolean := True;
      Pending    : Natural := 0;
      First_Byte : Natural := 0;
      Step       : Natural := 0;

      function Valid_First_Continuation
        (Byte_Value : Natural;
         Second     : Natural)
         return Boolean is
      begin
         if Byte_Value = 16#E0# and then Second < 16#A0# then
            return False;
         elsif Byte_Value = 16#ED# and then Second > 16#9F# then
            return False;
         elsif Byte_Value = 16#F0# and then Second < 16#90# then
            return False;
         elsif Byte_Value = 16#F4# and then Second > 16#8F# then
            return False;
         end if;

         return True;
      end Valid_First_Continuation;

      function Is_Continuation (Value : Natural) return Boolean is
      begin
         return Value >= 16#80# and then Value <= 16#BF#;
      end Is_Continuation;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_Value := Natural (Buffer (Index));

               if Pending > 0 then
                  if not Is_Continuation (Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  elsif Step = 1 and then not Valid_First_Continuation (First_Byte, Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  end if;

                  Pending := Pending - 1;
                  Step := Step + 1;
               elsif Byte_Value = 0 then
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               elsif Byte_Value <= 16#7F# then
                  null;
               elsif Byte_Value in 16#C2# .. 16#DF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 1;
                  Step := 1;
               elsif Byte_Value in 16#E0# .. 16#EF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 2;
                  Step := 1;
               elsif Byte_Value in 16#F0# .. 16#F4# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 3;
                  Step := 1;
               else
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               end if;
            end loop;
         end if;
      end loop;
      Ada.Streams.Stream_IO.Close (File);

      if Pending > 0 then
         return "binary";
      end if;

      return (if Ascii_Only then "ascii" else "utf8");
   exception
      when others =>
         Safe_Close (File);
         return "binary";
   end Text_Encoding_Name;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String is
   begin
      return Prefix & ".lines_encoding|" & Natural_Text (Count_Text_Lines (Path)) & "|" & Text_Encoding_Name (Path);
   end Text_Metadata_Token;

   function Pdf_Page_Count_Token (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 4096);
      Last   : Natural;
      Count  : Natural := 0;

      function Page_Marker_At
        (Line : String;
         Pos  : Positive)
         return Boolean
      is
         Marker_Last : constant Natural := Pos + String'("/Type /Page")'Length - 1;
      begin
         if Marker_Last > Line'Last then
            return False;
         elsif Line (Pos .. Marker_Last) /= "/Type /Page" then
            return False;
         elsif Marker_Last = Line'Last then
            return True;
         end if;

         declare
            Next : constant Character := Line (Marker_Last + 1);
         begin
            return Next = ' '
              or else Next = ASCII.HT
              or else Next = ASCII.LF
              or else Next = ASCII.CR
              or else Next = ASCII.VT
              or else Next = ASCII.FF
              or else Next = '/'
              or else Next = '>'
              or else Next = '<'
              or else Next = ']'
              or else Next = '[';
         end;
      end Page_Marker_At;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         if Last > 0 then
            declare
               Line : constant String := Buffer (1 .. Last);
               Pos  : Natural := Ada.Strings.Fixed.Index (Line, "/Type /Page");
            begin
               while Pos > 0 loop
                  if Page_Marker_At (Line, Pos) then
                     Count := Count + 1;
                  end if;
                  exit when Pos + 10 > Line'Last;
                  Pos := Ada.Strings.Fixed.Index (Line (Pos + 10 .. Line'Last), "/Type /Page");
               end loop;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return "document.pdf.pages|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return "document.kind|pdf";
   end Pdf_Page_Count_Token;

   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Count  : Natural := 0;
      Byte_0 : Ada.Streams.Stream_Element := 0;
      Byte_1 : Ada.Streams.Stream_Element := 0;
      Byte_2 : Ada.Streams.Stream_Element := 0;
      Byte_3 : Ada.Streams.Stream_Element := 0;
      Seen   : Natural := 0;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_0 := Byte_1;
               Byte_1 := Byte_2;
               Byte_2 := Byte_3;
               Byte_3 := Buffer (Index);
               if Seen < 4 then
                  Seen := Seen + 1;
               end if;

               if Seen = 4
                 and then Byte_0 = 16#50#
                 and then Byte_1 = 16#4B#
                 and then Byte_2 = 16#01#
                 and then Byte_3 = 16#02#
               then
                  Count := Count + 1;
               end if;
            end loop;
         end if;
      end loop;
      Stream_IO.Close (File);
      return Prefix & ".entries|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return Prefix & ".entries|0";
   end Zip_Entry_Count_Token;

   function Executable_Format_Token (Path : String) return String is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);
      Stream_IO.Close (File);

      if Last >= 4
        and then Buffer (1) = 16#7F#
        and then Character'Val (Buffer (2)) = 'E'
        and then Character'Val (Buffer (3)) = 'L'
        and then Character'Val (Buffer (4)) = 'F'
      then
         return "executable.format|elf";
      elsif Last >= 2
        and then Character'Val (Buffer (1)) = 'M'
        and then Character'Val (Buffer (2)) = 'Z'
      then
         return "executable.format|pe";
      elsif Last >= 2
        and then Character'Val (Buffer (1)) = '#'
        and then Character'Val (Buffer (2)) = '!'
      then
         return "executable.format|script";
      else
         return "executable.format|unknown";
      end if;
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Executable_Format_Token;

   function Directory_Count_Token (Path : String) return String is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Count     : Natural := 0;
      Started   : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return "";
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Count := Count + 1;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return "directory.count|" & Natural_Text (Count);
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return "";
   end Directory_Count_Token;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is
   begin
      return Natural (Value);
   end Stream_Byte;

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
   is
      package Stream_IO renames Ada.Streams.Stream_IO;
      use type Stream_IO.Count;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 32);
      Last   : Ada.Streams.Stream_Element_Offset;

      function Is_PNG return Boolean is
      begin
         return Last >= 24
           and then Buffer (1) = 16#89#
           and then Character'Val (Buffer (2)) = 'P'
           and then Character'Val (Buffer (3)) = 'N'
           and then Character'Val (Buffer (4)) = 'G'
           and then Buffer (5) = 16#0D#
           and then Buffer (6) = 16#0A#
           and then Buffer (7) = 16#1A#
           and then Buffer (8) = 16#0A#;
      end Is_PNG;

      function JPEG_Token return String is
         Segment_Buffer : Ada.Streams.Stream_Element_Array (1 .. 9);
         Segment_Last   : Ada.Streams.Stream_Element_Offset;
         Marker         : Ada.Streams.Stream_Element;
         Length_Value   : Natural;
         Remaining      : Natural;
      begin
         Stream_IO.Set_Index (File, 3);
         while not Stream_IO.End_Of_File (File) loop
            Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
            exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;

            loop
               Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
               exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;
            end loop;

            exit when Segment_Last < 1;
            Marker := Segment_Buffer (1);

            if Marker = 16#00# then
               null;
            elsif Marker in 16#D0# .. 16#D7# or else Marker = 16#01# then
               null;
            else
               exit when Marker = 16#D9# or else Marker = 16#DA#;
               Stream_IO.Read (File, Segment_Buffer (1 .. 2), Segment_Last);
               exit when Segment_Last < 2;
               Length_Value := U16_BE (Segment_Buffer, 1);
               exit when Length_Value < 2;

               if Marker in 16#C0# .. 16#C3# or else Marker in 16#C5# .. 16#C7#
                 or else Marker in 16#C9# .. 16#CB# or else Marker in 16#CD# .. 16#CF#
               then
                  Stream_IO.Read (File, Segment_Buffer (1 .. 5), Segment_Last);
                  if Segment_Last >= 5 then
                     return "image.dimensions|" &
                       Dimensions_Text (U16_BE (Segment_Buffer, 4), U16_BE (Segment_Buffer, 2));
                  end if;
                  return "";
               end if;

               Remaining := Length_Value - 2;
               if Remaining > 0 then
                  Stream_IO.Set_Index
                    (File,
                     Stream_IO.Positive_Count (Stream_IO.Count (Stream_IO.Index (File)) + Stream_IO.Count (Remaining)));
               end if;
            end if;
         end loop;

         return "";
      end JPEG_Token;
   begin
      if Filetype /= "image/png" and then Filetype /= "image/jpeg" then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);

      if Filetype = "image/png" and then Is_PNG then
         declare
            Token : constant String := "image.dimensions|" & Dimensions_Text (U32_BE (Buffer, 17), U32_BE (Buffer, 21));
         begin
            Stream_IO.Close (File);
            return Token;
         end;
      elsif Filetype = "image/jpeg"
        and then Last >= 2
        and then Buffer (1) = 16#FF#
        and then Buffer (2) = 16#D8#
      then
         declare
            Token : constant String := JPEG_Token;
         begin
            Stream_IO.Close (File);
            return Token;
         end;
      end if;

      Stream_IO.Close (File);
      return "";
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Image_Dimensions_Token;

   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return Directory_Count_Token (Path);
         when Files.Types.Executable_Item =>
            return Executable_Format_Token (Path);
         when Files.Types.Symlink_Item =>
            return Files.Platform.Metadata.Symlink_Target_Token (Path);
         when Files.Types.Regular_File_Item =>
            if Filetype = "text/plain" then
               return Text_Metadata_Token ("text", Path);
            elsif Filetype = "text/x-ada" then
               return Text_Metadata_Token ("source.ada", Path);
            elsif Filetype = "application/json" then
               return Text_Metadata_Token ("source.json", Path);
            elsif Filetype = "application/xml" then
               return Text_Metadata_Token ("source.xml", Path);
            elsif Filetype = "text/markdown" then
               return Text_Metadata_Token ("markdown", Path);
            elsif Filetype = "image/png" or else Filetype = "image/jpeg" then
               return Image_Dimensions_Token (Path, Filetype);
            elsif Filetype = "application/pdf" then
               return Pdf_Page_Count_Token (Path);
            elsif Filetype = "application/zip" then
               return Zip_Entry_Count_Token (Path, "archive.zip");
            elsif Filetype = "application/gzip-tar" then
               return "archive.format|gzip";
            elsif Filetype = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then
               return Zip_Entry_Count_Token (Path, "office.docx");
            elsif Filetype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then
               return Zip_Entry_Count_Token (Path, "office.xlsx");
            elsif Filetype = "application/x-tar" then
               return "archive.format|tar";
            elsif Filetype = "application/gzip" then
               return "archive.format|gzip";
            elsif Filetype = "audio/mpeg" or else Filetype = "audio/wav" then
               return "media.kind|audio";
            elsif Filetype = "video/mp4" then
               return "media.kind|video";
            end if;
         when others =>
            null;
      end case;

      return "";
   end Extra_Info_Token;

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind
   is
      Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
   begin
      if GNAT.OS_Lib.Is_Symbolic_Link (Full) then
         return Files.Types.Symlink_Item;
      end if;

      case Ada.Directories.Kind (Dir_Entry) is
         when Ada.Directories.Directory =>
            return Files.Types.Directory_Item;
         when Ada.Directories.Ordinary_File =>
            if GNAT.OS_Lib.Is_Executable_File (Full) then
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

   function Normalize_Path
     (Path : String)
      return Path_Result
   is
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return
           (Status         => Path_Missing,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.missing"));
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            return
              (Status         => Path_Valid,
               Directory_Path => To_Unbounded_String (Ada.Directories.Full_Name (Path)),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Ordinary_File =>
            return
              (Status         => Path_Valid,
               Directory_Path =>
                 To_Unbounded_String (Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Path))),
               Error_Key      => Null_Unbounded_String);
         when Ada.Directories.Special_File =>
            return
              (Status         => Path_Inaccessible,
               Directory_Path => Null_Unbounded_String,
               Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
      end case;
   exception
      when others =>
         return
           (Status         => Path_Inaccessible,
            Directory_Path => Null_Unbounded_String,
            Error_Key      => To_Unbounded_String ("error.path.inaccessible"));
   end Normalize_Path;

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
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
      Icon_Id  : constant String := Files.File_Types.Icon_Id_For (Settings, Kind, Filetype);
      Thumbnail_Cache : constant String := Default_Thumbnail_Cache_Directory (Parent_Path);
      Thumbnail_Path  : constant String := Thumbnail_Path_For (Full, Thumbnail_Cache);
      Thumbnail : constant Cached_Thumbnail :=
        Thumbnail_For_Item
          (Full_Path       => Full,
           Kind            => Kind,
           Filetype        => Filetype,
           Name            => Name,
           Icon_Id         => Icon_Id,
           Cache_Directory => Thumbnail_Cache,
           Thumbnail_Path  => Thumbnail_Path);
      Item : Directory_Item :=
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Full),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Filetype),
         Icon_Id            => To_Unbounded_String (Icon_Id),
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
   begin
      --  Filetype_Extra (folder item counts, document page/entry/line counts,
      --  symlink targets) is computed lazily for the selected item when the info
      --  pane needs it -- see Files.Model.Ensure_Selected_Item_Extra -- rather
      --  than here, where it would open every subfolder and read every document
      --  on load, making navigation slow. It stays empty at load time.
      begin
         if Kind /= Files.Types.Directory_Item then
            Item.Size := Long_Long_Integer (Ada.Directories.Size (Full));
            Item.Size_Available := True;
            if Thumbnail.Loaded then
               Item.Thumbnail_Available := True;
               Item.Thumbnail_Path := To_Unbounded_String (Thumbnail_Path);
               Item.Thumbnail_Width := Thumbnail.Width;
               Item.Thumbnail_Height := Thumbnail.Height;
               Item.Thumbnail_Pixels := Thumbnail.Pixels;
            end if;
         end if;
         Item.Creation_Time :=
           Files.Platform.Metadata.File_Creation_Time (Full, Item.Creation_Available);
         Item.Modified_Time := Ada.Directories.Modification_Time (Full);
         Item.Modified_Available := True;
         Item.Permissions := To_Unbounded_String (Permission_String (Full));
         Item.Mode_Bits :=
           Files.Platform.Metadata.File_Permission_Bits (Full, Item.Mode_Available);
         Files.Platform.Metadata.File_Ownership
           (Full, Item.Owner_Id, Item.Group_Id, Item.Ownership_Available);
      exception
         when others =>
            Item.Metadata_Error := True;
            Item.Error_Key := To_Unbounded_String ("error.metadata.read");
      end;

      return Item;
   end Item_For_Path;

   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result
   is
      Search : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Items  : Item_Vectors.Vector;
      Normalized_Path : Unbounded_String;
      Started : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Items     => Items,
            Error_Key => To_Unbounded_String ("error.directory.load"));
      end if;

      Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "."
              and then Name /= ".."
              and then (Settings.Show_Hidden_Files or else Name (Name'First) /= '.')
            then
               declare
                  Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
                  Kind : constant Files.Types.Item_Kind := Kind_From_Directory_Entry (Dir_Entry);
               begin
                  Items.Append
                    (Item_For_Path (Full, Name, To_String (Normalized_Path), Kind, Settings));
               end;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);

      Sort_Items (Items, Settings.Sort_Field_Value, Settings.Sort_Ascending);

      return
        (Success   => True,
         Path      => Normalized_Path,
         Items     => Items,
         Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Items     => Items,
            Error_Key => To_Unbounded_String ("error.directory.load"));
   end Load_Directory;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
   is
      Empty : Directory_Item;
   begin
      if Full_Path = "" or else not Ada.Directories.Exists (Full_Path) then
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.missing"));
      end if;

      declare
         Full   : constant String := Ada.Directories.Full_Name (Full_Path);
         Name   : constant String := Ada.Directories.Simple_Name (Full);
         Parent : constant String := Ada.Directories.Containing_Directory (Full);
         Kind   : Files.Types.Item_Kind;
      begin
         if GNAT.OS_Lib.Is_Symbolic_Link (Full) then
            Kind := Files.Types.Symlink_Item;
         else
            case Ada.Directories.Kind (Full) is
               when Ada.Directories.Directory =>
                  Kind := Files.Types.Directory_Item;
               when Ada.Directories.Ordinary_File =>
                  if GNAT.OS_Lib.Is_Executable_File (Full) then
                     Kind := Files.Types.Executable_Item;
                  else
                     Kind := Files.Types.Regular_File_Item;
                  end if;
               when Ada.Directories.Special_File =>
                  Kind := Files.Types.Other_Item;
            end case;
         end if;

         return
           (Success   => True,
            Item      => Item_For_Path (Full, Name, Parent, Kind, Settings),
            Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.inaccessible"));
   end Load_Item;

   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
   is
      Result : Recursive_Search_Result :=
        (Success   => False,
         Root_Path => To_Unbounded_String (Root_Path),
         Query     => To_Unbounded_String (Query),
         Items     => Item_Vectors.Empty_Vector,
         Error_Key => Null_Unbounded_String);
      Normalized_Query : constant String := Files.Types.To_Lower (Query);

      function Matches (Name : UString) return Boolean is
      begin
         return Normalized_Query = ""
           or else Ada.Strings.Fixed.Index
             (Files.Types.To_Lower (To_String (Name)), Normalized_Query) > 0;
      end Matches;

      procedure Visit (Directory_Path : String) is
         Load : constant Directory_Load_Result := Load_Directory (Directory_Path, Settings);
      begin
         if not Load.Success or else Natural (Result.Items.Length) >= Max_Items then
            return;
         end if;

         for Item of Load.Items loop
            exit when Natural (Result.Items.Length) >= Max_Items;
            if Matches (Item.Name) then
               Result.Items.Append (Item);
            end if;
         end loop;

         for Item of Load.Items loop
            exit when Natural (Result.Items.Length) >= Max_Items;
            if Item.Kind = Files.Types.Directory_Item then
               Visit (To_String (Item.Full_Path));
            end if;
         end loop;
      exception
         when others =>
            null;
      end Visit;
   begin
      if not Files.Fs.Directory_Exists (Root_Path)
      then
         Result.Error_Key := To_Unbounded_String ("error.directory.load");
         return Result;
      end if;

      Result.Root_Path := To_Unbounded_String (Ada.Directories.Full_Name (Root_Path));
      Visit (Root_Path);
      Result.Success := True;
      return Result;
   exception
      when others =>
         Result.Success := False;
         Result.Error_Key := To_Unbounded_String ("error.search.failed");
         return Result;
   end Search_Recursive;

   function Directory_State
     (Path : String)
      return Directory_Signature
   is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
      Result    : Directory_Signature :=
        (Path                  => To_Unbounded_String (Path),
         Exists                => False,
         Entry_Count           => 0,
         Entry_State_Checksum  => 0,
         Latest_Modified       => Ada.Calendar.Time_Of (1901, 1, 1),
         Latest_Modified_Known => False);

      function Entry_Checksum
        (Name : String;
         Kind : Ada.Directories.File_Kind;
         Size : Long_Long_Integer)
         return Natural
      is
         Modulus : constant Long_Long_Integer := 1_000_000_007;
         Value   : Long_Long_Integer := Long_Long_Integer (Ada.Directories.File_Kind'Pos (Kind) + 1);
      begin
         for Character_Value of Name loop
            Value :=
              (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
         end loop;

         Value := (Value * 131 + Long_Long_Integer'Max (0, Size)) mod Modulus;
         return Natural (Value);
      end Entry_Checksum;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return Result;
      end if;

      Result.Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
      Result.Exists := True;
      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Entry_Count := Result.Entry_Count + 1;
               declare
                  Full     : constant String := Ada.Directories.Full_Name (Dir_Entry);
                  Kind     : Ada.Directories.File_Kind := Ada.Directories.Special_File;
                  Size     : Long_Long_Integer := 0;
                  Modified : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
               begin
                  begin
                     Kind := Ada.Directories.Kind (Dir_Entry);
                  exception
                     when others =>
                        null;
                  end;

                  if Kind = Ada.Directories.Ordinary_File then
                     begin
                        Size := Long_Long_Integer (Ada.Directories.Size (Full));
                     exception
                        when others =>
                           Size := 0;
                     end;
                  end if;

                  Result.Entry_State_Checksum :=
                    (Result.Entry_State_Checksum + Entry_Checksum (Name, Kind, Size)) mod 1_000_000_007;

                  begin
                     Modified := Ada.Directories.Modification_Time (Full);
                     if not Result.Latest_Modified_Known
                       or else Modified > Result.Latest_Modified
                     then
                        Result.Latest_Modified := Modified;
                        Result.Latest_Modified_Known := True;
                     end if;
                  exception
                     when others =>
                        null;
                  end;
               exception
                  when others =>
                     Result.Entry_State_Checksum :=
                       (Result.Entry_State_Checksum
                        + Entry_Checksum (Name, Ada.Directories.Special_File, 0)) mod 1_000_000_007;
               end;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return Result;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return Result;
   end Directory_State;

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

   function Root_Label (Path : String; Kind : Root_Kind) return String is
   begin
      case Kind is
         when Root_Filesystem =>
            return (if Path = "/" then "root.filesystem" else Path);
         when Root_Home =>
            return "root.home";
         when Root_Current =>
            return "root.current";
         when Root_Mount =>
            return "root.mount|" & Ada.Directories.Simple_Name (Path);
         when Root_User_Mount =>
            return "root.user_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Network_Mount =>
            return "root.network_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Windows_Drive =>
            return "root.drive|" & Path;
         when Root_Favorite =>
            return "root.favorite|" & Ada.Directories.Simple_Name (Path);
      end case;
   exception
      when others =>
         return Path;
   end Root_Label;

   function Available_Root_Entries return Root_Entry_Vectors.Vector is
      Roots : Root_Entry_Vectors.Vector;
      Home                    : constant String := Safe_Environment_Value ("HOME");
      User_Profile            : constant String := Safe_Environment_Value ("USERPROFILE");
      Xdg_Runtime_Dir         : constant String := Safe_Environment_Value ("XDG_RUNTIME_DIR");
      User_Name               : constant String := Safe_Environment_Value ("USER");
      Home_Drive              : constant String := Safe_Environment_Value ("HOMEDRIVE");
      Home_Path               : constant String := Safe_Environment_Value ("HOMEPATH");
      System_Drive            : constant String := Safe_Environment_Value ("SystemDrive");
      Home_Share              : constant String := Safe_Environment_Value ("HOMESHARE");
      One_Drive               : constant String := Safe_Environment_Value ("OneDrive");
      One_Drive_Commercial    : constant String := Safe_Environment_Value ("OneDriveCommercial");
      One_Drive_Consumer      : constant String := Safe_Environment_Value ("OneDriveConsumer");
      Home_Drive_Profile      : constant String :=
        (if Home_Drive /= "" and then Home_Path /= "" then Home_Drive & Home_Path else "");

      function Field_From
        (Line  : String;
         Index : Positive)
         return String
      is
         Current : Positive := 1;
         Start   : Natural := 0;
      begin
         for Position in Line'Range loop
            if Line (Position) /= ' ' and then Start = 0 then
               Start := Position;
            elsif Line (Position) = ' ' and then Start /= 0 then
               if Current = Index then
                  return Line (Start .. Position - 1);
               end if;
               Current := Current + 1;
               Start := 0;
            end if;
         end loop;

         if Start /= 0 and then Current = Index then
            return Line (Start .. Line'Last);
         end if;

         return "";
      end Field_From;

      function Starts_With
        (Text   : String;
         Prefix : String)
         return Boolean is
      begin
         return Text'Length >= Prefix'Length
           and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Is_Pseudo_Mount_Type (Filesystem_Type : String) return Boolean is
         Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
      begin
         return Normalized = ""
           or else Normalized = "autofs"
           or else Normalized = "binfmt_misc"
           or else Normalized = "bpf"
           or else Normalized = "cgroup"
           or else Normalized = "cgroup2"
           or else Normalized = "configfs"
           or else Normalized = "debugfs"
           or else Normalized = "devpts"
           or else Normalized = "devtmpfs"
           or else Normalized = "efivarfs"
           or else Normalized = "fusectl"
           or else Normalized = "hugetlbfs"
           or else Normalized = "mqueue"
           or else Normalized = "nsfs"
           or else Normalized = "overlay"
           or else Normalized = "proc"
           or else Normalized = "pstore"
           or else Normalized = "ramfs"
           or else Normalized = "rpc_pipefs"
           or else Normalized = "securityfs"
           or else Normalized = "squashfs"
           or else Normalized = "sysfs"
           or else Normalized = "tmpfs"
           or else Normalized = "tracefs";
      end Is_Pseudo_Mount_Type;

      function Is_Network_Filesystem_Type (Filesystem_Type : String) return Boolean is
         Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
      begin
         return Normalized = "9p"
           or else Normalized = "afpfs"
           or else Normalized = "cifs"
           or else Normalized = "davfs"
           or else Normalized = "fuse.gvfsd-fuse"
           or else Normalized = "fuse.sshfs"
           or else Normalized = "ncpfs"
           or else Normalized = "nfs"
           or else Normalized = "nfs4"
           or else Normalized = "smb3"
           or else Normalized = "sshfs";
      end Is_Network_Filesystem_Type;

      function Root_Kind_For_Mount
        (Mount_Point     : String;
         Filesystem_Type : String)
         return Root_Kind is
      begin
         if Is_Network_Filesystem_Type (Filesystem_Type)
           or else Starts_With (Mount_Point, "//")
           or else Starts_With (Mount_Point, "\\")
           or else Starts_With (Mount_Point, "/run/user/")
         then
            return Root_Network_Mount;
         end if;

         return Root_Mount;
      end Root_Kind_For_Mount;

      function Is_User_Visible_Mount_Point (Mount_Point : String) return Boolean is
         Runtime_Gvfs : constant String :=
           (if Xdg_Runtime_Dir = "" then "" else Join_Path (Xdg_Runtime_Dir, "gvfs"));

         function Is_Mount_Container return Boolean is
         begin
            return Mount_Point = "/mnt"
              or else Mount_Point = "/media"
              or else Mount_Point = "/run/media"
              or else Mount_Point = "/Volumes"
              or else Mount_Point = "/System/Volumes"
              or else (Runtime_Gvfs /= "" and then Mount_Point = Runtime_Gvfs);
         end Is_Mount_Container;
      begin
         return not Is_Mount_Container
           and then
             (Mount_Point = "/"
           or else Starts_With (Mount_Point, "/mnt/")
           or else Starts_With (Mount_Point, "/media/")
           or else Starts_With (Mount_Point, "/run/media/")
           or else Starts_With (Mount_Point, "/Volumes/")
           or else Starts_With (Mount_Point, "/System/Volumes/")
           or else
             (Runtime_Gvfs /= ""
              and then Starts_With (Mount_Point, Runtime_Gvfs & "/")));
      end Is_User_Visible_Mount_Point;

      function Is_Displayable_Root_Mount
        (Mount_Point     : String;
         Filesystem_Type : String)
         return Boolean is
      begin
         return Is_User_Visible_Mount_Point (Mount_Point)
           and then not Is_Pseudo_Mount_Type (Filesystem_Type);
      end Is_Displayable_Root_Mount;

      function Filesystem_Type_For (Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Buffer : String (1 .. 4096);
         Last   : Natural;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return "";
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Line        : constant String := Buffer (1 .. Last);
               Mount_Point : constant String := Field_From (Line, 2);
            begin
               if Mount_Point = Path then
                  Ada.Text_IO.Close (File);
                  return Field_From (Line, 3);
               end if;
            end;
         end loop;

         Ada.Text_IO.Close (File);
         return "";
      exception
         when others =>
            Safe_Close (File);
            return "";
      end Filesystem_Type_For;

      function Contains_Root (Path : String) return Boolean is
      begin
         for Root of Roots loop
            if To_String (Root.Path) = Path then
               return True;
            end if;
         end loop;

         return False;
      end Contains_Root;

      procedure Append_If_Directory
        (Path : String;
         Kind : Root_Kind)
      is
         Full : Unbounded_String;
         Name : Unbounded_String;
         Label : Unbounded_String;
         Effective_Kind : Root_Kind := Kind;
      begin
         if Files.Fs.Directory_Exists (Path)
         then
            Full := To_Unbounded_String (Ada.Directories.Full_Name (Path));
            Name := To_Unbounded_String (Ada.Directories.Simple_Name (To_String (Full)));
            if Length (Name) = 0 then
               Name := Full;
            end if;
            if Kind in Root_Mount | Root_User_Mount | Root_Network_Mount | Root_Filesystem then
               declare
                  Filesystem_Type : constant String := Filesystem_Type_For (To_String (Full));
               begin
                  if Kind in Root_Mount | Root_User_Mount
                    and then Is_Network_Filesystem_Type (Filesystem_Type)
                  then
                     Effective_Kind := Root_Network_Mount;
                  end if;

                  Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
                  if Filesystem_Type /= "" and then Ada.Strings.Fixed.Index (To_String (Label), "|") > 0 then
                     Append (Label, "|");
                     Append (Label, Filesystem_Type);
                  end if;
               end;
            else
               Label := To_Unbounded_String (Root_Label (To_String (Full), Effective_Kind));
            end if;
            if not Contains_Root (To_String (Full)) then
               Roots.Append
                 (Root_Entry'
                    (Path  => Full,
                     Label => Label,
                     Kind  => Effective_Kind,
                     Volume_Name => Name,
                     Ready => Root_Ready,
                     Removable => Effective_Kind = Root_Mount or else Effective_Kind = Root_User_Mount));
            end if;
         end if;
      exception
         when others =>
            null;
      end Append_If_Directory;

      procedure Append_Children
        (Parent : String;
         Kind   : Root_Kind)
      is
         Search : Ada.Directories.Search_Type;
         Child  : Ada.Directories.Directory_Entry_Type;
         Started : Boolean := False;
      begin
         if not Ada.Directories.Exists (Parent)
           or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
         then
            return;
         end if;

         Ada.Directories.Start_Search
           (Search,
            Directory => Parent,
            Pattern   => "*",
            Filter    =>
              [Ada.Directories.Ordinary_File => False,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False]);
         Started := True;

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Child);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Child);
               Full : constant String := Ada.Directories.Full_Name (Child);
            begin
               if Name /= "." and then Name /= ".." then
                  if User_Name /= ""
                    and then (Parent = "/media" or else Parent = "/run/media")
                    and then Name = User_Name
                  then
                     Append_Children (Full, Kind);
                  else
                     Append_If_Directory (Full, Kind);
                  end if;
               end if;
            end;
         end loop;

         Safe_End_Search (Search, Started);
      exception
         when others =>
            Safe_End_Search (Search, Started);
            null;
      end Append_Children;

      procedure Append_Proc_Mounts is
         File   : Ada.Text_IO.File_Type;
         Buffer : String (1 .. 4096);
         Last   : Natural;

         function Octal_Value (Value : Character) return Natural is
         begin
            if Value in '0' .. '7' then
               return Character'Pos (Value) - Character'Pos ('0');
            else
               return Natural'Last;
            end if;
         end Octal_Value;

         function Decode_Mount_Escapes (Value : String) return String is
            Result : Unbounded_String;
            Index  : Natural := Value'First;
         begin
            while Index <= Value'Last loop
               if Value (Index) = '\'
                 and then Index + 3 <= Value'Last
                 and then Octal_Value (Value (Index + 1)) /= Natural'Last
                 and then Octal_Value (Value (Index + 2)) /= Natural'Last
                 and then Octal_Value (Value (Index + 3)) /= Natural'Last
               then
                  declare
                     Code : constant Natural :=
                       Octal_Value (Value (Index + 1)) * 64
                       + Octal_Value (Value (Index + 2)) * 8
                       + Octal_Value (Value (Index + 3));
                  begin
                     if Code <= Character'Pos (Character'Last) then
                        Append (Result, Character'Val (Code));
                        Index := Index + 4;
                     else
                        Append (Result, Value (Index));
                        Index := Index + 1;
                     end if;
                  end;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end loop;

            return To_String (Result);
         end Decode_Mount_Escapes;

         function Mount_Field
           (Line  : String;
            Index : Positive)
            return String is
         begin
            return Decode_Mount_Escapes (Field_From (Line, Index));
         end Mount_Field;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return;
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Line            : constant String := Buffer (1 .. Last);
               Mount_Point     : constant String := Mount_Field (Line, 2);
               Filesystem_Type : constant String := Field_From (Line, 3);
            begin
               if Is_Displayable_Root_Mount (Mount_Point, Filesystem_Type) then
                  Append_If_Directory (Mount_Point, Root_Kind_For_Mount (Mount_Point, Filesystem_Type));
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when others =>
            Safe_Close (File);
      end Append_Proc_Mounts;
   begin
      Append_If_Directory ("/", Root_Filesystem);
      Append_Proc_Mounts;
      if Home /= "" then
         Append_If_Directory (Home, Root_Home);
      end if;
      if User_Profile /= "" then
         Append_If_Directory (User_Profile, Root_Home);
      end if;
      Append_If_Directory (Ada.Directories.Current_Directory, Root_Current);
      Append_Children ("/mnt", Root_Mount);
      Append_Children ("/media", Root_Mount);
      Append_Children ("/run/media", Root_User_Mount);
      Append_Children ("/Volumes", Root_Mount);
      Append_Children ("/System/Volumes", Root_Mount);
      if Xdg_Runtime_Dir /= "" then
         Append_Children (Join_Path (Xdg_Runtime_Dir, "gvfs"), Root_Network_Mount);
      end if;
      if User_Name /= "" then
         declare
            Run_Media_User : constant String := "/run/media/" & User_Name;
         begin
            Append_Children (Run_Media_User, Root_User_Mount);
         end;
      end if;

      for Drive in Character range 'A' .. 'Z' loop
         Append_If_Directory (String'(1 => Drive) & ":\", Root_Windows_Drive);
      end loop;
      if Home_Drive /= "" then
         Append_If_Directory (Home_Drive & "\", Root_Windows_Drive);
      end if;
      if Home_Drive_Profile /= "" then
         Append_If_Directory (Home_Drive_Profile, Root_User_Mount);
      end if;
      if System_Drive /= "" then
         Append_If_Directory (System_Drive & "\", Root_Windows_Drive);
      end if;
      if Home_Share /= "" then
         Append_If_Directory (Home_Share, Root_Network_Mount);
      end if;
      if One_Drive /= "" then
         Append_If_Directory (One_Drive, Root_User_Mount);
      end if;
      if One_Drive_Commercial /= "" then
         Append_If_Directory (One_Drive_Commercial, Root_User_Mount);
      end if;
      if One_Drive_Consumer /= "" then
         Append_If_Directory (One_Drive_Consumer, Root_User_Mount);
      end if;

      if Roots.Is_Empty then
         declare
            Full : constant String := Ada.Directories.Full_Name (Ada.Directories.Current_Directory);
         begin
            Roots.Append
              (Root_Entry'
                 (Path  => To_Unbounded_String (Full),
                  Label => To_Unbounded_String (Root_Label (Full, Root_Current)),
                  Kind  => Root_Current,
                  Volume_Name => To_Unbounded_String (Ada.Directories.Simple_Name (Full)),
                  Ready => Root_Ready,
                  Removable => False));
         end;
      end if;

      declare
         function Less (Left : Root_Entry; Right : Root_Entry) return Boolean is
         begin
            return To_String (Left.Path) < To_String (Right.Path);
         end Less;

         package Sorting is new Root_Entry_Vectors.Generic_Sorting ("<" => Less);
      begin
         Sorting.Sort (Roots);
      end;

      return Roots;
   end Available_Root_Entries;

   function Available_Roots return Files.Types.String_Vectors.Vector is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Roots   : Files.Types.String_Vectors.Vector;
   begin
      for Root of Entries loop
         Roots.Append (Root.Path);
      end loop;

      return Roots;
   end Available_Roots;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Result  : Root_Discovery_Diagnostics :=
        (Root_Count              => Natural (Entries.Length),
         Ready_Count             => 0,
         Removable_Count         => 0,
         Windows_Drive_Count     => 0,
         Mount_Count             => 0,
         User_Mount_Count        => 0,
         Network_Mount_Count     => 0,
         Duplicate_Paths_Removed => True,
         Deterministic_Order     => True);
   begin
      for Root of Entries loop
         if Root.Ready = Root_Ready then
            Result.Ready_Count := Result.Ready_Count + 1;
         end if;

         if Root.Removable then
            Result.Removable_Count := Result.Removable_Count + 1;
         end if;

         case Root.Kind is
            when Root_Windows_Drive =>
               Result.Windows_Drive_Count := Result.Windows_Drive_Count + 1;
            when Root_Mount =>
               Result.Mount_Count := Result.Mount_Count + 1;
            when Root_User_Mount =>
               Result.User_Mount_Count := Result.User_Mount_Count + 1;
            when Root_Network_Mount =>
               Result.Network_Mount_Count := Result.Network_Mount_Count + 1;
            when others =>
               null;
         end case;
      end loop;

      return Result;
   end Root_Discovery_Status;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities is
      Has_Proc_Mounts : constant Boolean := Ada.Directories.Exists ("/proc/mounts");
      Has_Sys_Block   : constant Boolean := Ada.Directories.Exists ("/sys/block");
      Has_Statvfs     : constant Boolean :=
        Files.Platform.Metadata.Volume_Capacity_Of ("/").Available;
   begin
      return
        (Labels_From_Platform_Api    => False,
         Readiness_From_Platform_Api => True,
         Removable_From_Platform_Api => Has_Sys_Block,
         Capacity_From_Platform_Api  => Has_Statvfs,
         Filesystem_Type_Available   => Has_Proc_Mounts,
         Eject_Available             => False,
         Native_Api_Name             =>
           To_Unbounded_String
             ((if Has_Statvfs and then Has_Proc_Mounts and then Has_Sys_Block then
                  "statvfs+proc.mounts+sysfs"
               elsif Has_Statvfs and then Has_Proc_Mounts then "statvfs+proc.mounts"
               elsif Has_Statvfs then "statvfs"
               elsif Has_Proc_Mounts and then Has_Sys_Block then "proc.mounts+sysfs"
               elsif Has_Proc_Mounts then "proc.mounts"
               elsif Has_Sys_Block then "sysfs"
               else "none")),
         Native_Binding_Status       =>
           (if Has_Statvfs or else Has_Proc_Mounts or else Has_Sys_Block
            then Native_API_Binding_Available
            else Native_API_Binding_Missing),
         Binding_Unit                => To_Unbounded_String ("Files.File_System"),
         Source_Device_Available     => Has_Proc_Mounts,
         Mount_Options_Available     => Has_Proc_Mounts,
         Network_Metadata_Available  => Has_Proc_Mounts,
         Removable_Status_Available  => Has_Sys_Block,
         Capacity_Bytes_Known        => Has_Statvfs,
         Free_Bytes_Known            => Has_Statvfs,
         Inode_Count_Known           => Has_Statvfs,
         Read_Only_Available         => Has_Statvfs,
         Name_Max_Available          => Has_Statvfs);
   end Root_Volume_Capabilities_Of_Current_Environment;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile is
   begin
      return
        (Permission_Errors_Recoverable => True,
         Symlink_Items_Represented     => True,
         Special_File_Items_Represented => True,
         Cross_Device_Rename_Recoverable => True,
         Trash_Preflight               => True,
         Metadata_Partial_Items        => True,
         Removable_Root_Metadata       => True,
         Native_Root_Volume_Details    => True);
   end Filesystem_Edge_Case_Profile_Of_Current_Environment;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
   is
      Caps : constant Root_Volume_Capabilities := Root_Volume_Capabilities_Of_Current_Environment;
   begin
      case Adapter is
         when Native_Adapter_Linux =>
            return
              (Adapter               => Native_Adapter_Linux,
               Trash_Binding_Status  =>
                 (if Trash_Backend_Of_Current_Environment in
                   Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home
                  then Native_API_Binding_Available
                  else Native_API_Binding_Missing),
               Volume_Binding_Status => Caps.Native_Binding_Status,
               Trash_API_Name        => To_Unbounded_String ("freedesktop.trash"),
               Volume_API_Name       => Caps.Native_Api_Name,
               Trash_Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
               Volume_Binding_Unit   => To_Unbounded_String ("Files.File_System.Root_Volume_Details_For"),
               Required_Library      => To_Unbounded_String ("libc"),
               Required_Framework    => Null_Unbounded_String,
               Current_Target        => True,
               Trash_Can_Execute     => Trash_Is_Available,
               Volume_Can_Query      => Caps.Capacity_Bytes_Known or else Caps.Filesystem_Type_Available);
         when Native_Adapter_Windows =>
            return Files.Platform.Windows.API_Profile;
         when Native_Adapter_Macos =>
            return Files.Platform.Macos.API_Profile;
         when Native_Adapter_None =>
            return
              (Adapter               => Native_Adapter_None,
               Trash_Binding_Status  => Native_API_Binding_Missing,
               Volume_Binding_Status => Native_API_Binding_Missing,
               Trash_API_Name        => To_Unbounded_String ("none"),
               Volume_API_Name       => To_Unbounded_String ("none"),
               Trash_Binding_Unit    => To_Unbounded_String ("none"),
               Volume_Binding_Unit   => To_Unbounded_String ("none"),
               Required_Library      => Null_Unbounded_String,
               Required_Framework    => Null_Unbounded_String,
               Current_Target        => False,
               Trash_Can_Execute     => False,
               Volume_Can_Query      => False);
      end case;
   end Native_Platform_API_Profile_For;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info)
   is
      Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
        Files.Platform.Metadata.Volume_Capacity_Of (Path);
   begin
      Info :=
        (Capacity_Bytes   => Capacity.Capacity_Bytes,
         Free_Bytes       => Capacity.Free_Bytes,
         Inode_Count      => Capacity.Inode_Count,
         Free_Inode_Count => Capacity.Free_Inode_Count,
         Name_Max         => Capacity.Name_Max,
         Read_Only        => Capacity.Read_Only,
         Known            => Capacity.Available,
         Inodes_Known     => Capacity.Inodes_Known,
         Name_Max_Known   => Capacity.Name_Max_Known,
         Read_Only_Known  => Capacity.Read_Only_Known);
   end Volume_Size_For;

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String
   is
      Current : Positive := 1;
      Start   : Natural := 0;
   begin
      for Position in Line'Range loop
         if Line (Position) /= ' ' and then Start = 0 then
            Start := Position;
         elsif Line (Position) = ' ' and then Start /= 0 then
            if Current = Index then
               return Line (Start .. Position - 1);
            end if;
            Current := Current + 1;
            Start := 0;
         end if;
      end loop;

      if Start /= 0 and then Current = Index then
         return Line (Start .. Line'Last);
      end if;

      return "";
   end Mount_Field;

   function Simple_Device_Name (Source : String) return String is
      Start : Natural := Source'First;
   begin
      for Index in reverse Source'Range loop
         if Source (Index) = '/' then
            Start := Index + 1;
            exit;
         end if;
      end loop;

      if Start > Source'Last then
         return "";
      end if;

      return Source (Start .. Source'Last);
   end Simple_Device_Name;

   function Parent_Block_Device_Name (Device : String) return String is
      Last : Natural := Device'Last;
   begin
      if Device = "" then
         return "";
      end if;

      while Last >= Device'First and then Device (Last) in '0' .. '9' loop
         Last := Last - 1;
      end loop;

      if Last >= Device'First and then Device (Last) = 'p' then
         Last := Last - 1;
      end if;

      if Last < Device'First then
         return Device;
      end if;

      return Device (Device'First .. Last);
   end Parent_Block_Device_Name;

   function Read_First_Line (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 256);
      Last   : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Ada.Text_IO.Get_Line (File, Buffer, Last);
      Ada.Text_IO.Close (File);
      return Buffer (1 .. Last);
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Read_First_Line;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean
   is
      Device : constant String := Simple_Device_Name (Source);
      Parent : constant String := Parent_Block_Device_Name (Device);
      Value  : Unbounded_String;
   begin
      Known := False;
      if Device = "" or else Ada.Strings.Fixed.Index (Source, "/dev/") /= Source'First then
         return False;
      end if;

      Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Device & "/removable"));
      if To_String (Value) = "" and then Parent /= Device then
         Value := To_Unbounded_String (Read_First_Line ("/sys/block/" & Parent & "/removable"));
      end if;

      if To_String (Value) = "" then
         return False;
      end if;

      Known := True;
      return To_String (Value) = "1";
   end Removable_Status_For;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 4096);
      Last   : Natural;
      Result : Mount_Metadata;
   begin
      if not Ada.Directories.Exists ("/proc/mounts") then
         return Result;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         declare
            Line        : constant String := Buffer (1 .. Last);
            Mount_Point : constant String := Mount_Field (Line, 2);
         begin
            if Mount_Point = Path then
               declare
                  Source : constant String := Mount_Field (Line, 1);
                  Known  : Boolean := False;
               begin
                  Ada.Text_IO.Close (File);
                  Result.Source_Device := To_Unbounded_String (Source);
                  Result.Filesystem_Type := To_Unbounded_String (Mount_Field (Line, 3));
                  Result.Mount_Options := To_Unbounded_String (Mount_Field (Line, 4));
                  Result.Removable := Removable_Status_For (Source, Known);
                  Result.Removable_Known := Known;
                  Result.Found := True;
                  return Result;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return Result;
   exception
      when others =>
         Safe_Close (File);
         return (others => <>);
   end Mount_Metadata_For_Root;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
   is
      Path_Text : constant String := To_String (Root.Path);

      function Path_Is_Queryable return Boolean is
      begin
         if Path_Text = "" then
            return False;
         end if;

         for Character_Value of Path_Text loop
            if Character'Pos (Character_Value) < 32
              or else Character'Pos (Character_Value) = 127
            then
               return False;
            end if;
         end loop;

         return True;
      end Path_Is_Queryable;

      Queryable : constant Boolean := Path_Is_Queryable;
      Mount     : constant Mount_Metadata :=
        (if Queryable then Mount_Metadata_For_Root (Path_Text) else (others => <>));
      Volume    : Volume_Size_Info := (others => <>);

      function Adapter_Name return String is
         Has_Statvfs : constant Boolean := Volume.Known;
         Has_Proc    : constant Boolean := Mount.Found;
         Has_Sysfs   : constant Boolean := Mount.Removable_Known;
      begin
         if Has_Statvfs and then Has_Proc and then Has_Sysfs then
            return "statvfs+proc.mounts+sysfs";
         elsif Has_Statvfs and then Has_Proc then
            return "statvfs+proc.mounts";
         elsif Has_Statvfs then
            return "statvfs";
         elsif Has_Proc and then Has_Sysfs then
            return "proc.mounts+sysfs";
         elsif Has_Proc then
            return "proc.mounts";
         elsif Has_Sysfs then
            return "sysfs";
         else
            return "none";
         end if;
      end Adapter_Name;

      function Network_Filesystem_Type (Filesystem_Type : String) return Boolean is
         Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
      begin
         return Normalized = "9p"
           or else Normalized = "afpfs"
           or else Normalized = "cifs"
           or else Normalized = "davfs"
           or else Normalized = "fuse.gvfsd-fuse"
           or else Normalized = "fuse.sshfs"
           or else Normalized = "ncpfs"
           or else Normalized = "nfs"
           or else Normalized = "nfs4"
           or else Normalized = "smb3"
           or else Normalized = "sshfs";
      end Network_Filesystem_Type;

      function Path_Starts_With (Prefix : String) return Boolean is
      begin
         return Path_Text'Length >= Prefix'Length
           and then Path_Text (Path_Text'First .. Path_Text'First + Prefix'Length - 1) = Prefix;
      end Path_Starts_With;

      function Network_Root return Boolean is
      begin
         return Root.Kind = Root_Network_Mount
           or else Network_Filesystem_Type (To_String (Mount.Filesystem_Type))
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\");
      end Network_Root;

      function Remote_Protocol_For return String is
         Path_Lower : constant String := Files.Types.To_Lower (Path_Text);
         Type_Lower : constant String := Files.Types.To_Lower (To_String (Mount.Filesystem_Type));
      begin
         if Type_Lower = "cifs" or else Type_Lower = "smb3" then
            return "smb";
         elsif Type_Lower = "nfs" or else Type_Lower = "nfs4" then
            return "nfs";
         elsif Type_Lower = "sshfs" or else Type_Lower = "fuse.sshfs" then
            return "sshfs";
         elsif Type_Lower = "davfs" then
            return "webdav";
         elsif Type_Lower = "afpfs" then
            return "afp";
         elsif Type_Lower = "9p" then
            return "9p";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "smb-share:") > 0
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\")
         then
            return "smb";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "sftp:") > 0 then
            return "sftp";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "dav:") > 0
           or else Ada.Strings.Fixed.Index (Path_Lower, "davs:") > 0
         then
            return "webdav";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "afp-volume:") > 0 then
            return "afp";
         elsif Type_Lower = "fuse.gvfsd-fuse"
           or else Ada.Strings.Fixed.Index (Path_Lower, "/gvfs/") > 0
         then
            return "gvfs";
         elsif Network_Root then
            return "unknown";
         else
            return "";
         end if;
      end Remote_Protocol_For;

      function Auth_May_Be_Required_For (Protocol : String) return Boolean is
      begin
         return Protocol = "afp"
           or else Protocol = "sftp"
           or else Protocol = "smb"
           or else Protocol = "sshfs"
           or else Protocol = "webdav";
      end Auth_May_Be_Required_For;
   begin
      if Queryable then
         Volume_Size_For (Path_Text, Volume);
      end if;

      declare
         Is_Network : constant Boolean := Network_Root;
         Protocol   : constant String := Remote_Protocol_For;
      begin
         return
           (Path                 => Root.Path,
            Label                => Root.Volume_Name,
            Native_Api_Name      => To_Unbounded_String (Adapter_Name),
            Filesystem_Type      => Mount.Filesystem_Type,
            Source_Device        => Mount.Source_Device,
            Mount_Options        => Mount.Mount_Options,
            Capacity_Bytes       => Volume.Capacity_Bytes,
            Free_Bytes           => Volume.Free_Bytes,
            Inode_Count          => Volume.Inode_Count,
            Free_Inode_Count     => Volume.Free_Inode_Count,
            Capacity_Known       => Volume.Known,
            Free_Known           => Volume.Known,
            Inode_Count_Known    => Volume.Inodes_Known,
            Free_Inode_Known     => Volume.Inodes_Known,
            Read_Only            => Volume.Read_Only,
            Read_Only_Known      => Volume.Read_Only_Known,
            Name_Max             => Volume.Name_Max,
            Name_Max_Known       => Volume.Name_Max_Known,
            Removable_Known      => Mount.Removable_Known,
            Removable            => Mount.Removable,
            Ejectable            => False,
            Network_Mount        => Is_Network,
            Remote_Protocol      => To_Unbounded_String (Protocol),
            Offline_Possible     => Is_Network,
            Auth_May_Be_Required => Is_Network and then Auth_May_Be_Required_For (Protocol),
            Latency_Sensitive    => Is_Network,
            Special_Error_Recovery => Is_Network,
            Uses_Platform_Detail =>
              Volume.Known
              or else Volume.Inodes_Known
              or else Volume.Read_Only_Known
              or else Volume.Name_Max_Known
              or else Mount.Found
              or else Mount.Removable_Known);
      end;
   end Root_Volume_Details_For;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy is
   begin
      return
        (Uses_Extension_Mapping     => True,
         Uses_Mime_Sniffing         => False,
         Parses_Image_Dimensions    => True,
         Parses_Text_Encoding       => True,
         Parses_Archive_Entry_Count => True,
         Parses_Pdf_Page_Markers    => True,
         Parses_Media_Codecs        => False,
         Parses_Office_Package_Info => True);
   end Filetype_Metadata_Policy_Of_Current_Implementation;

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

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String is
   begin
      if Parent_Path = "" then
         return Name;
      end if;

      return Ada.Directories.Compose
        (Containing_Directory => Parent_Path,
         Name                 => Name);
   end Join_Path;

   function Windows_Device_Basename (Name : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of Name loop
         exit when Character_Value = '.';
         Append (Result, Ada.Characters.Handling.To_Upper (Character_Value));
      end loop;

      declare
         Text : constant String := To_String (Result);
         Last : Natural := Text'Last;
      begin
         while Last >= Text'First and then Text (Last) = ' ' loop
            Last := Last - 1;
         end loop;

         if Last < Text'First then
            return "";
         else
            return Text (Text'First .. Last);
         end if;
      end;
   end Windows_Device_Basename;

   function Is_Windows_Device_Name (Name : String) return Boolean is
      Base : constant String := Windows_Device_Basename (Name);
   begin
      return Base = "CON"
        or else Base = "PRN"
        or else Base = "AUX"
        or else Base = "NUL"
        or else Base = "CONIN$"
        or else Base = "CONOUT$"
        or else
          (Base'Length = 4
           and then (Base (Base'First .. Base'First + 2) = "COM"
                     or else Base (Base'First .. Base'First + 2) = "LPT")
           and then Base (Base'Last) in '1' .. '9');
   end Is_Windows_Device_Name;

   function Is_All_Whitespace (Name : String) return Boolean is
      Position : Natural := 0;
      Length   : Natural;
   begin
      if Name = "" then
         return True;
      end if;

      while Position < Name'Length loop
         Length := Files.UTF8.Whitespace_Separator_Length (Name, Position);
         if Length = 0 then
            return False;
         end if;

         Position := Position + Length;
      end loop;

      return True;
   end Is_All_Whitespace;

   function Ends_With_Whitespace (Name : String) return Boolean is
      Position : Natural := 0;
      Length   : Natural;
      Last     : Boolean := False;
   begin
      while Position < Name'Length loop
         Length := Files.UTF8.Whitespace_Separator_Length (Name, Position);
         Last := Length > 0 and then Position + Length = Name'Length;
         if Length = 0 then
            declare
               Next_Position : constant Natural := Files.UTF8.Next_Boundary (Name, Position);
            begin
               if Next_Position <= Position then
                  return False;
               end if;

               Position := Next_Position;
            end;
         else
            Position := Position + Length;
         end if;
      end loop;

      return Last;
   end Ends_With_Whitespace;

   function Valid_Leaf_Name (Name : String) return Boolean is
      Index     : Integer := Name'First;
      Codepoint : Natural := 0;
   begin
      if Name = ""
        or else Name = "."
        or else Name = ".."
        or else Name (Name'Last) = ' '
        or else Name (Name'Last) = '.'
        or else Is_Windows_Device_Name (Name)
        or else not Files.UTF8.Is_Valid (Name)
        or else Is_All_Whitespace (Name)
        or else Ends_With_Whitespace (Name)
      then
         return False;
      end if;

      while Index <= Name'Last loop
         Files.UTF8.Decode_Next_Codepoint (Name, Index, Codepoint);

         if Codepoint < 32
           or else Codepoint = 127
           or else Codepoint in 16#80# .. 16#9F#
         then
            return False;
         elsif Codepoint < 128 then
            declare
               Character_Value : constant Character := Character'Val (Codepoint);
            begin
               if Character_Value = '/'
                 or else Character_Value = '\'
                 or else Character_Value = '<'
                 or else Character_Value = '>'
                 or else Character_Value = ':'
                 or else Character_Value = Character'Val (34)
                 or else Character_Value = '|'
                 or else Character_Value = '?'
                 or else Character_Value = '*'
               then
                  return False;
               end if;
            end;
         end if;
      end loop;

      return True;
   end Valid_Leaf_Name;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
   is
      Candidate : Unbounded_String := To_Unbounded_String ("untitled.txt");
      Counter   : Positive := 2;

      function Counter_Text return String is
         Image : constant String := Positive'Image (Counter);
      begin
         if Image'Length > 0 and then Image (Image'First) = ' ' then
            return Image (Image'First + 1 .. Image'Last);
         end if;

         return Image;
      end Counter_Text;
   begin
      while Ada.Directories.Exists (Join_Path (Directory_Path, To_String (Candidate))) loop
         Candidate := To_Unbounded_String ("untitled " & Counter_Text & ".txt");
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;

      return To_String (Candidate);
   exception
      when others =>
         return "untitled.txt";
   end Next_Untitled_Name;

   function Trash_Is_Available return Boolean is
   begin
      return Path_Can_Be_Directory (Trash_Base_Path);
   end Trash_Is_Available;

   function Trash_Backend_Of_Current_Environment return Trash_Backend is
   begin
      return Trash_Backend_For_Base;
   end Trash_Backend_Of_Current_Environment;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      case Backend is
         when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
            return
              (Backend             => Backend,
               Native_Platform     => True,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => True,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Backend             => Backend,
               Native_Platform     => False,
               Xdg_Compatible      => Backend /= Trash_Macos_Home,
               Metadata_Sidecar    => True,
               Collision_Safe_Name => True,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
         when Trash_Unavailable =>
            return
              (Backend             => Trash_Unavailable,
               Native_Platform     => False,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => False,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
      end case;
   end Trash_Capabilities_Of_Current_Environment;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result is
   begin
      case Request.Backend is
         when Trash_Windows_Recycle_Bin =>
            return Files.Platform.Windows.Evaluate_Trash (Request);
         when Trash_Macos_Native =>
            return Files.Platform.Macos.Evaluate_Trash (Request);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Supported        => True,
               Attempted        => False,
               Completed        => False,
               Native_Binding_Available => False,
               Native_Binding_Status => Native_API_Binding_Missing,
               Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
               Desktop_Standard => Request.Backend /= Trash_Macos_Home,
               Would_Delete     => False,
               Uses_Recycle_Bin => False,
               Adapter_Name     =>
                 To_Unbounded_String
                   ((if Request.Backend = Trash_Macos_Home then "macos.home_trash" else "xdg.trash")),
               Native_Api_Name  =>
                 To_Unbounded_String
                   ((if Request.Backend = Trash_Macos_Home then "filesystem.rename" else "freedesktop.trash")),
               Operation_Name   => To_Unbounded_String ("move_to_trash"),
               Requires_User_Consent => False,
               Preserves_Metadata    => True,
               Error_Key        => Null_Unbounded_String);
         when Trash_Unavailable =>
            return
              (Supported        => False,
               Attempted        => False,
               Completed        => False,
               Native_Binding_Available => False,
               Native_Binding_Status => Native_API_Binding_Missing,
               Binding_Unit    => To_Unbounded_String ("none"),
               Desktop_Standard => False,
               Would_Delete     => False,
               Uses_Recycle_Bin => False,
               Adapter_Name     => To_Unbounded_String ("none"),
               Native_Api_Name  => To_Unbounded_String ("none"),
               Operation_Name   => To_Unbounded_String ("none"),
               Requires_User_Consent => False,
               Preserves_Metadata    => False,
               Error_Key        => To_Unbounded_String ("error.trash.unavailable"));
      end case;
   end Evaluate_Native_Trash;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
   is
      Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
      Mutation   : Mutation_Result;
   begin
      case Request.Backend is
         when Trash_Windows_Recycle_Bin =>
            return Files.Platform.Windows.Move_To_Recycle_Bin (Request);
         when Trash_Macos_Native =>
            return Files.Platform.Macos.Move_To_Trash (Request);
         when others =>
            null;
      end case;

      if not Evaluation.Supported then
         return
           (Supported             => False,
            Attempted             => False,
            Completed             => False,
            Native_Binding_Available => Evaluation.Native_Binding_Available,
            Native_Binding_Status => Evaluation.Native_Binding_Status,
            Binding_Unit          => Evaluation.Binding_Unit,
            Desktop_Standard      => Evaluation.Desktop_Standard,
            Would_Delete          => Evaluation.Would_Delete,
            Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
            Adapter_Name          => Evaluation.Adapter_Name,
            Native_Api_Name       => Evaluation.Native_Api_Name,
            Operation_Name        => Evaluation.Operation_Name,
            Requires_User_Consent => Evaluation.Requires_User_Consent,
            Preserves_Metadata    => Evaluation.Preserves_Metadata,
            Error_Key             => Evaluation.Error_Key);
      end if;

      Mutation := Move_To_Trash (To_String (Request.Path));
      return
        (Supported             => True,
         Attempted             => True,
         Completed             => Mutation.Success,
         Native_Binding_Available => Evaluation.Native_Binding_Available,
         Native_Binding_Status => Evaluation.Native_Binding_Status,
         Binding_Unit          => Evaluation.Binding_Unit,
         Desktop_Standard      => Evaluation.Desktop_Standard,
         Would_Delete          => False,
         Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
         Adapter_Name          => Evaluation.Adapter_Name,
         Native_Api_Name       => Evaluation.Native_Api_Name,
         Operation_Name        => Evaluation.Operation_Name,
         Requires_User_Consent => Evaluation.Requires_User_Consent,
         Preserves_Metadata    => Evaluation.Preserves_Metadata,
         Error_Key             => Mutation.Error_Key);
   end Execute_Native_Trash;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
   is
      Base : constant String := Trash_Base_Path;

      function Source_Exists return Boolean is
      begin
         return Path /= "" and then Ada.Directories.Exists (Path);
      exception
         when others =>
            return False;
      end Source_Exists;

      function Normalized_Text (Value : String) return String is
      begin
         if Value = "" then
            return "";
         elsif Ada.Directories.Exists (Value) then
            return Ada.Directories.Full_Name (Value);
         else
            return Value;
         end if;
      exception
         when others =>
            return Value;
      end Normalized_Text;

      function Is_Same_Or_Inside
        (Child  : String;
         Parent : String)
         return Boolean
      is
         Clean_Child  : constant String := Normalized_Text (Child);
         Clean_Parent : constant String := Normalized_Text (Parent);
         Next         : Natural;
      begin
         if Clean_Child = "" or else Clean_Parent = "" then
            return False;
         elsif Clean_Child = Clean_Parent then
            return True;
         elsif Clean_Child'Length <= Clean_Parent'Length then
            return False;
         elsif Clean_Child (Clean_Child'First .. Clean_Child'First + Clean_Parent'Length - 1) /= Clean_Parent then
            return False;
         end if;

         if Clean_Parent (Clean_Parent'Last) = '/'
           or else Clean_Parent (Clean_Parent'Last) = '\'
         then
            return True;
         end if;

         Next := Clean_Child'First + Clean_Parent'Length;
         return Clean_Child (Next) = '/' or else Clean_Child (Next) = '\';
      exception
         when others =>
            return False;
      end Is_Same_Or_Inside;
   begin
      if Trash_Backend_For_Base = Trash_Windows_Recycle_Bin
        or else Trash_Backend_For_Base = Trash_Macos_Native
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.native_unavailable"));
      elsif not Source_Exists then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      elsif Base = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.unavailable"));
      elsif not Path_Can_Be_Directory (Base) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.unavailable"));
      elsif Is_Same_Or_Inside (Base, Path)
        or else Is_Same_Or_Inside (Path, Base)
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Move_To_Trash_Preflight;

   function Mutation_Leaf_Name (Path : String) return String is
   begin
      if Path = "" then
         return "";
      end if;

      return Ada.Directories.Simple_Name (Path);
   exception
      when others =>
         return "";
   end Mutation_Leaf_Name;

   function Create_Empty_File
     (Path : String)
      return Mutation_Result
   is
      File    : Ada.Text_IO.File_Type;
      Created : Boolean := False;

      procedure Delete_Created_File_If_Present is
      begin
         if Created
           and then Files.Fs.File_Exists (Path)
         then
            Ada.Directories.Delete_File (Path);
         end if;
      exception
         when others =>
            null;
      end Delete_Created_File_If_Present;

      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Created := True;
      Ada.Text_IO.Close (File);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         Delete_Created_File_If_Present;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Empty_File;

   function Create_Directory
     (Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Path);
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      Ada.Directories.Create_Directory (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.create"));
   end Create_Directory;

   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result
   is
      function Exists_Safely (Path : String) return Boolean is
      begin
         return Path /= "" and then Files.Fs.Exists (Path);
      exception
         when others =>
            return False;
      end Exists_Safely;

      function Same_Existing_Path return Boolean is
      begin
         if From_Path = "" or else To_Path = "" then
            return False;
         end if;

         return Exists_Safely (From_Path)
           and then Exists_Safely (To_Path)
           and then Ada.Directories.Full_Name (From_Path) = Ada.Directories.Full_Name (To_Path);
      exception
         when others =>
            return From_Path = To_Path and then Exists_Safely (From_Path);
      end Same_Existing_Path;

      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (To_Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (To_Path);
   begin
      if not Exists_Safely (From_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.source_missing"));
      elsif Same_Existing_Path then
         return (Success => True, Error_Key => Null_Unbounded_String);
      elsif To_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.invalid_destination"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Exists_Safely (To_Path)
        or else Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.invalid_destination"));
      end if;

      Ada.Directories.Rename (From_Path, To_Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.failed"));
   end Rename_Item;

   function Supports_Permissions return Boolean is
   begin
      return Files.Platform.Metadata.Permissions_Supported;
   end Supports_Permissions;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.File_Permission_Bits (Path, Available);
   end Permission_Bits_Of;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
   is
      function Exists_Safely (Candidate : String) return Boolean is
      begin
         return Candidate /= "" and then Files.Fs.Exists (Candidate);
      exception
         when others =>
            return False;
      end Exists_Safely;
   begin
      if not Files.Platform.Metadata.Permissions_Supported then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.unsupported"));
      elsif not Exists_Safely (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
      elsif Files.Platform.Metadata.Set_Permissions (Path, Mode) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permissions.failed"));
   end Set_Permissions;

   function Supports_Ownership return Boolean is
   begin
      return Files.Platform.Metadata.Ownership_Supported;
   end Supports_Ownership;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean) is
   begin
      Files.Platform.Metadata.File_Ownership (Path, User_Id, Group_Id, Available);
   end Ownership_Of;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
   is
      function Exists_Safely (Candidate : String) return Boolean is
      begin
         return Candidate /= "" and then Files.Fs.Exists (Candidate);
      exception
         when others =>
            return False;
      end Exists_Safely;
   begin
      if not Files.Platform.Metadata.Ownership_Supported then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.unsupported"));
      elsif not Exists_Safely (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      elsif Files.Platform.Metadata.Set_Ownership (Path, User_Id, Group_Id) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.ownership.denied"));
   end Set_Ownership;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.User_Id_For_Name (Name, Found);
   end User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural is
   begin
      return Files.Platform.Metadata.Group_Id_For_Name (Name, Found);
   end Group_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
      Position : constant Id_Name_Maps.Cursor := User_Name_Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String := Files.Platform.Metadata.User_Name_For_Id (Id);
      begin
         User_Name_Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end User_Name_For_Id;

   function Group_Name_For_Id (Id : Natural) return String is
      Position : constant Id_Name_Maps.Cursor := Group_Name_Cache.Find (Id);
   begin
      if Id_Name_Maps.Has_Element (Position) then
         return To_String (Id_Name_Maps.Element (Position));
      end if;
      declare
         Name : constant String := Files.Platform.Metadata.Group_Name_For_Id (Id);
      begin
         Group_Name_Cache.Insert (Id, To_Unbounded_String (Name));
         return Name;
      end;
   end Group_Name_For_Id;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
   is
      Result  : Directory_Size_Result;
      Visited : Natural := 0;

      function Saturating_Long_Add
        (Left  : Long_Long_Integer;
         Right : Long_Long_Integer)
         return Long_Long_Integer is
      begin
         if Right > 0 and then Left > Long_Long_Integer'Last - Right then
            return Long_Long_Integer'Last;
         else
            return Left + Right;
         end if;
      end Saturating_Long_Add;

      function Is_Symlink (Candidate : String) return Boolean is
      begin
         return Files.Platform.Metadata.Symlink_Target_Token (Candidate) /= "";
      exception
         when others =>
            return False;
      end Is_Symlink;

      procedure Walk (Directory : String; Depth : Natural) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
      begin
         if Depth > Max_Depth then
            Result.Capped := True;
            return;
         end if;

         Ada.Directories.Start_Search
           (Search    => Search,
            Directory => Directory,
            Pattern   => "",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => True]);

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
               Full : constant String := Ada.Directories.Full_Name (Item);
            begin
               if Name /= "." and then Name /= ".." then
                  Visited := Visited + 1;
                  if Visited > Max_Entries then
                     Result.Capped := True;
                     Ada.Directories.End_Search (Search);
                     return;
                  end if;

                  Result.Item_Count := Result.Item_Count + 1;

                  if Is_Symlink (Full) then
                     null;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Directory then
                     Walk (Full, Depth + 1);
                     exit when Result.Capped;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Ordinary_File then
                     Result.File_Count := Result.File_Count + 1;
                     Result.Total_Bytes :=
                       Saturating_Long_Add
                         (Result.Total_Bytes,
                          Long_Long_Integer (Ada.Directories.Size (Item)));
                  end if;
               end if;
            exception
               when others =>
                  --  Skip individual entries that cannot be classified or sized
                  --  (races, permission denials) without aborting the walk.
                  null;
            end;
         end loop;

         Ada.Directories.End_Search (Search);
      exception
         when others =>
            --  An unreadable subdirectory is skipped rather than failing the
            --  whole measurement.
            null;
      end Walk;
   begin
      if Path = ""
        or else not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
      then
         return Result;
      end if;

      Walk (Path, 0);
      Result.Available := True;
      return Result;
   exception
      when others =>
         return Result;
   end Directory_Size;

   --  Shared destination validation for the create-link commands: the new link
   --  path must be a valid, currently-unused leaf inside an existing directory.
   function Validate_Link_Destination
     (Link_Path : String)
      return Mutation_Result
   is
      function Parent_Directory return String is
      begin
         return Ada.Directories.Containing_Directory (Link_Path);
      exception
         when others =>
            return "";
      end Parent_Directory;

      Parent : constant String := Parent_Directory;
      Name   : constant String := Mutation_Leaf_Name (Link_Path);
   begin
      if Link_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Valid_Leaf_Name (Name) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.name.invalid"));
      elsif Ada.Directories.Exists (Link_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.exists"));
      elsif Parent = ""
        or else not Ada.Directories.Exists (Parent)
        or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Validate_Link_Destination;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
   is
      Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
   begin
      if Source_Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Validation.Success then
         return Validation;
      elsif Files.Platform.Metadata.Create_Symbolic_Link (Source_Path, Link_Path) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
   end Create_Symbolic_Link;

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
   is
      Validation : constant Mutation_Result := Validate_Link_Destination (Link_Path);
   begin
      if Source_Path = ""
        or else not Ada.Directories.Exists (Source_Path)
        or else Ada.Directories.Kind (Source_Path) = Ada.Directories.Directory
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      elsif not Validation.Success then
         return Validation;
      elsif Files.Platform.Metadata.Create_Hard_Link (Source_Path, Link_Path) then
         return (Success => True, Error_Key => Null_Unbounded_String);
      else
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
      end if;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.link.failed"));
   end Create_Hard_Link;

   --  Recursively copy a file/directory tree. Used as the cross-device
   --  fallback when Ada.Directories.Rename fails with EXDEV (it cannot move
   --  across filesystems), by both trashing and drag-and-drop moves.
   procedure Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
   is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      case Ada.Directories.Kind (Source_Path) is
         when Ada.Directories.Directory =>
            Ada.Directories.Create_Directory (Destination_Path);
            Ada.Directories.Start_Search
              (Search,
               Directory => Source_Path,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => True]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     Copy_Tree
                       (Ada.Directories.Full_Name (Dir_Entry),
                        Join_Path (Destination_Path, Name));
                  end if;
               end;
            end loop;
            Safe_End_Search (Search, Started);
         when Ada.Directories.Ordinary_File =>
            Ada.Directories.Copy_File (Source_Path, Destination_Path);
         when Ada.Directories.Special_File =>
            Ada.Directories.Copy_File (Source_Path, Destination_Path);
      end case;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         raise;
   end Copy_Tree;

   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
      return Mutation_Result is
   begin
      Copy_Tree (Source_Path, Destination_Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.copy.failed"));
   end Copy_Tree;

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

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
   is
      function Unsafe_Target return Boolean is
      begin
         if Path = ""
           or else Path = "/"
           or else (Path'Length = 3 and then Path (Path'First + 1 .. Path'First + 2) = ":\")
         then
            return True;
         end if;

         declare
            Full   : constant String := Ada.Directories.Full_Name (Path);
            Parent : constant String := Ada.Directories.Containing_Directory (Full);
         begin
            return Full = ""
              or else Full = Parent
              or else (Full'Length = 1 and then Full (Full'First) = '/');
         end;
      exception
         when others =>
            return True;
      end Unsafe_Target;
   begin
      if Unsafe_Target then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.refused"));
      elsif not Ada.Directories.Exists (Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.source_missing"));
      end if;

      --  Files.Fs.Delete_Tree removes a directory tree; a single
      --  file must go through Delete_File.
      if Files.Fs.Directory_Exists (Path) then
         Files.Fs.Delete_Tree (Path);
      else
         Ada.Directories.Delete_File (Path);
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.permanent_delete.failed"));
   end Delete_Permanently;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
      Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
      Base    : constant String := Trash_Base_Path;
   begin
      if not Removed.Success then
         return Removed;
      end if;

      --  Freedesktop backends keep a <base>/info/<name>.trashinfo sidecar next
      --  to the payload; remove it so the emptied entry leaves no orphaned
      --  metadata. Sidecar removal is best-effort and never fails the purge.
      if Base /= "" and then Backend in Trash_Xdg_Data_Home | Trash_Home_Data then
         declare
            Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
            Info_Path : constant String :=
              Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
         begin
            if Ada.Directories.Exists (Info_Path) then
               Ada.Directories.Delete_File (Info_Path);
            end if;
         exception
            when others =>
               null;
         end;
      end if;

      return Removed;
   end Delete_Trashed_Item;

   function Restore_From_Trash
     (Trashed_Path : String)
      return Mutation_Result
   is
      --  Reverse of Move_To_Trash's Trash_Info_Path_Value percent-encoder.
      function Url_Decode (Value : String) return String is
         Result : Unbounded_String;
         Index  : Natural := Value'First;

         function Hex_Value (Item : Character) return Integer is
         begin
            case Item is
               when '0' .. '9' =>
                  return Character'Pos (Item) - Character'Pos ('0');
               when 'A' .. 'F' =>
                  return Character'Pos (Item) - Character'Pos ('A') + 10;
               when 'a' .. 'f' =>
                  return Character'Pos (Item) - Character'Pos ('a') + 10;
               when others =>
                  return -1;
            end case;
         end Hex_Value;
      begin
         while Index <= Value'Last loop
            if Value (Index) = '%' and then Index + 2 <= Value'Last then
               declare
                  High : constant Integer := Hex_Value (Value (Index + 1));
                  Low  : constant Integer := Hex_Value (Value (Index + 2));
               begin
                  if High >= 0 and then Low >= 0 then
                     Append (Result, Character'Val (High * 16 + Low));
                     Index := Index + 3;
                  else
                     Append (Result, Value (Index));
                     Index := Index + 1;
                  end if;
               end;
            else
               Append (Result, Value (Index));
               Index := Index + 1;
            end if;
         end loop;

         return To_String (Result);
      end Url_Decode;

      --  Read and URL-decode the Path= value from a trashinfo sidecar.
      function Read_Original_Path (Info_File_Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Result : Unbounded_String;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Info_File_Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               if Line'Length >= 5
                 and then Line (Line'First .. Line'First + 4) = "Path="
               then
                  Result := To_Unbounded_String (Url_Decode (Line (Line'First + 5 .. Line'Last)));
                  exit;
               end if;
            end;
         end loop;
         Safe_Close (File);
         return To_String (Result);
      exception
         when others =>
            Safe_Close (File);
            return "";
      end Read_Original_Path;

      Backend   : constant Trash_Backend := Trash_Backend_For_Base;
      Base      : constant String := Trash_Base_Path;
   begin
      if Base = ""
        or else Backend not in Trash_Xdg_Data_Home | Trash_Home_Data
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;

      declare
         Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
         Info_Path : constant String :=
           Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
         Original  : Unbounded_String;
         Parent    : Unbounded_String;
      begin
         if not Ada.Directories.Exists (Info_Path) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
         end if;

         Original := To_Unbounded_String (Read_Original_Path (Info_Path));
         if Length (Original) = 0 then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end if;

         Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (To_String (Original)));
         if To_String (Parent) = ""
           or else not Ada.Directories.Exists (To_String (Parent))
           or else Ada.Directories.Kind (To_String (Parent)) /= Ada.Directories.Directory
         then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
         end if;

         if Ada.Directories.Exists (To_String (Original)) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
         end if;

         begin
            Ada.Directories.Rename (Trashed_Path, To_String (Original));
         exception
            when others =>
               --  Cross-device (EXDEV): rename cannot move across filesystems,
               --  so fall back to copy-then-delete just like Move_To_Trash.
               begin
                  Copy_Tree (Trashed_Path, To_String (Original));
               exception
                  when others =>
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
               end;
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
               begin
                  if not Removed.Success then
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
                  end if;
               end;
         end;

         begin
            if Ada.Directories.Exists (Info_Path) then
               Ada.Directories.Delete_File (Info_Path);
            end if;
         exception
            when others =>
               null;
         end;

         return (Success => True, Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore_From_Trash;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
   is
      Result : Drop_Import_Result :=
        (Success   => False,
         Plans     => Drop_Import_Plan_Vectors.Empty_Vector,
         Error_Key => Null_Unbounded_String);
      --  Destinations already assigned earlier in this batch. They do not yet
      --  exist on disk, so without tracking them two sources sharing a simple
      --  name (from different directories) would resolve to the same target and
      --  the second would silently overwrite the first.
      Claimed : Files.Types.String_Vectors.Vector;

      function Image_No_Space (Value : Natural) return String is
         Image : constant String := Natural'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Image_No_Space;

      function Extension_Start (Name : String) return Natural is
      begin
         for Index in reverse Name'Range loop
            if Name (Index) = '.' and then Index > Name'First then
               return Index;
            end if;
         end loop;
         return 0;
      end Extension_Start;

      function Is_Claimed (Path : String) return Boolean is
      begin
         for Existing of Claimed loop
            if To_String (Existing) = Path then
               return True;
            end if;
         end loop;
         return False;
      end Is_Claimed;

      function Available_Destination (Leaf : String) return String is
         Dot       : constant Natural := Extension_Start (Leaf);
         Stem      : constant String :=
           (if Dot = 0 then Leaf else Leaf (Leaf'First .. Dot - 1));
         Extension : constant String :=
           (if Dot = 0 then "" else Leaf (Dot .. Leaf'Last));
         Counter   : Positive := 2;
         Candidate : Unbounded_String := To_Unbounded_String (Leaf);
         Full      : Unbounded_String :=
           To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
      begin
         while Ada.Directories.Exists (To_String (Full)) or else Is_Claimed (To_String (Full)) loop
            Candidate := To_Unbounded_String (Stem & " " & Image_No_Space (Counter) & Extension);
            Full := To_Unbounded_String (Join_Path (Destination_Directory, To_String (Candidate)));
            exit when Counter = Positive'Last;
            Counter := Counter + 1;
         end loop;
         return To_String (Full);
      end Available_Destination;

      --  True when Inner is Outer itself or a descendant of Outer (normalized).
      function Is_Within_Tree (Inner : String; Outer : String) return Boolean is
         I : constant String := Ada.Directories.Full_Name (Inner);
         O : constant String := Ada.Directories.Full_Name (Outer);
      begin
         return I = O
           or else (I'Length > O'Length
                    and then I (I'First .. I'First + O'Length - 1) = O
                    and then I (I'First + O'Length) = '/');
      end Is_Within_Tree;
   begin
      if not Files.Fs.Directory_Exists (Destination_Directory)
      then
         Result.Error_Key := To_Unbounded_String ("error.drop.invalid_destination");
         return Result;
      end if;

      for Source of Source_Paths loop
         declare
            Source_Text : constant String := To_String (Source);
            Leaf        : Unbounded_String;
            Plan        : Drop_Import_Plan;
         begin
            Plan.Source_Path := Source;
            Plan.Mode := Mode;
            if not Ada.Directories.Exists (Source_Text) then
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.drop.invalid_source");
               Result.Plans.Append (Plan);
               Result.Error_Key := Plan.Error_Key;
            else
               Leaf := To_Unbounded_String (Ada.Directories.Simple_Name (Source_Text));
               if not Valid_Leaf_Name (To_String (Leaf)) then
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.name.invalid");
                  Result.Error_Key := Plan.Error_Key;
               elsif Is_Within_Tree (Destination_Directory, Source_Text) then
                  --  Refuse to copy or move a directory into itself or one of
                  --  its own descendants; Execute_Drop_Import's recursive copy
                  --  would otherwise recurse without bound.
                  Plan.Valid := False;
                  Plan.Error_Key := To_Unbounded_String ("error.drop.into_self");
                  Result.Error_Key := Plan.Error_Key;
               else
                  Plan.Valid := True;
                  if Mode = Drop_Move
                    and then Ada.Directories.Full_Name
                               (Ada.Directories.Containing_Directory (Source_Text))
                             = Ada.Directories.Full_Name (Destination_Directory)
                  then
                     --  Moving an item into the directory it already lives in is
                     --  a no-op; keep its own path so Execute_Drop_Import skips
                     --  it instead of creating a numbered duplicate. (A copy
                     --  into the same directory still makes a numbered copy.)
                     Plan.Destination_Path := Source;
                  else
                     Plan.Destination_Path := To_Unbounded_String (Available_Destination (To_String (Leaf)));
                  end if;
                  Claimed.Append (Plan.Destination_Path);
                  Plan.Error_Key := Null_Unbounded_String;
               end if;
               Result.Plans.Append (Plan);
            end if;
         exception
            when others =>
               Result.Plans.Append
                 (Drop_Import_Plan'
                    (Source_Path      => Source,
                     Destination_Path => Null_Unbounded_String,
                     Mode             => Mode,
                     Valid            => False,
                     Error_Key        => To_Unbounded_String ("error.drop.failed")));
               Result.Error_Key := To_Unbounded_String ("error.drop.failed");
         end;
      end loop;

      Result.Success := Length (Result.Error_Key) = 0;
      return Result;
   end Plan_Drop_Import;

   function Execute_Drop_Import
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result
   is
   begin
      for Plan of Plans loop
         if not Plan.Valid then
            return
              (Success   => False,
               Error_Key =>
                 (if Length (Plan.Error_Key) > 0
                  then Plan.Error_Key
                  else To_Unbounded_String ("error.drop.failed")));
         end if;
      end loop;

      for Plan of Plans loop
         declare
            Source_Path      : constant String := To_String (Plan.Source_Path);
            Destination_Path : constant String := To_String (Plan.Destination_Path);
         begin
            if Plan.Mode = Drop_Move then
               if Source_Path /= Destination_Path then
                  begin
                     Ada.Directories.Rename (Source_Path, Destination_Path);
                  exception
                     when others =>
                        Copy_Tree (Source_Path, Destination_Path);
                        declare
                           Delete_Result : constant Mutation_Result := Delete_Permanently (Source_Path);
                        begin
                           if not Delete_Result.Success then
                              return Delete_Result;
                           end if;
                        end;
                  end;
               end if;
            else
               Copy_Tree (Source_Path, Destination_Path);
            end if;
         end;
      end loop;

      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         return
           (Success   => False,
           Error_Key => To_Unbounded_String ("error.drop.failed"));
   end Execute_Drop_Import;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is
      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);
      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Pixbuf : System.Address := System.Null_Address;
      Result : Decoded_Image;
   begin
      Pixbuf :=
        Gdk_Pixbuf_New_From_File_At_Size
          (Filename => C_Path,
           Width    => C_Int (Max_Size),
           Height   => C_Int (Max_Size),
           Error    => System.Null_Address);
      Interfaces.C.Strings.Free (C_Path);

      if Pixbuf = System.Null_Address then
         return Result;
      end if;

      declare
         Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
         Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
         Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
         Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
         Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
         Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
           Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
      begin
         if Width = 0
           or else Height = 0
           or else Width > Max_Size
           or else Height > Max_Size
           or else Channels < 3
           or else Rowstride < Width * Channels
           or else Pixels_Address = System.Null_Address
           or else Raw = null
         then
            G_Object_Unref (Pixbuf);
            return Result;
         end if;

         --  Copy row-major RGBA (alpha from the source or opaque when absent),
         --  matching the byte layout the icon-atlas thumbnail rasterizer reads.
         for Row in 0 .. Height - 1 loop
            for Column in 0 .. Width - 1 loop
               declare
                  Offset : constant Natural := Row * Rowstride + Column * Channels;
               begin
                  Result.Pixels.Append (Raw.all (Offset));
                  Result.Pixels.Append (Raw.all (Offset + 1));
                  Result.Pixels.Append (Raw.all (Offset + 2));
                  Result.Pixels.Append (if Channels >= 4 then Raw.all (Offset + 3) else 255);
               end;
            end loop;
         end loop;

         G_Object_Unref (Pixbuf);
         Result.Available := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   exception
      when others =>
         Safe_Free (C_Path);
         if Pixbuf /= System.Null_Address then
            G_Object_Unref (Pixbuf);
         end if;
         return (Available => False, Width => 0, Height => 0,
                 Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Decode_Image_To_Pixels;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
   is
      File : Ada.Text_IO.File_Type;

      function Clamp_Channel (Value : Natural) return Natural is
      begin
         return Value mod 256;
      end Clamp_Channel;

      function File_Size_Signal return Natural is
      begin
         return Natural (Long_Long_Integer'Min (Long_Long_Integer (Ada.Directories.Size (Source_Path)), 65_535));
      exception
         when others =>
            return 0;
      end File_Size_Signal;

      type Rgb_Pixel is record
         Red   : Natural := 0;
         Green : Natural := 0;
         Blue  : Natural := 0;
      end record;

      package Pixel_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Rgb_Pixel);

      package Thumbnail_Byte_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Ada.Streams.Stream_Element);

      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);

      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      function Byte_At
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural is
      begin
         if Index >= Natural (Data.Length) then
            return 0;
         end if;

         return Natural (Data.Element (Index));
      end Byte_At;

      function U32_BE_From
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural is
      begin
         return
           Byte_At (Data, Index) * 16#1000000#
           + Byte_At (Data, Index + 1) * 16#10000#
           + Byte_At (Data, Index + 2) * 16#100#
           + Byte_At (Data, Index + 3);
      end U32_BE_From;

      function Bytes_To_Stream_Array
        (Data : Thumbnail_Byte_Vectors.Vector)
         return Ada.Streams.Stream_Element_Array
      is
         Result : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Data.Length) - 1);
      begin
         for Index in 0 .. Natural (Data.Length) - 1 loop
            Result (Ada.Streams.Stream_Element_Offset (Index)) := Data.Element (Index);
         end loop;

         return Result;
      end Bytes_To_Stream_Array;

      procedure Write_Pixels_As_Ppm
        (Target_Path   : String;
         Pixels        : Pixel_Vectors.Vector;
         Source_Width  : Natural;
         Source_Height : Natural)
      is
         Output : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Target_Path);
         Ada.Text_IO.Put_Line (Output, "P3");
         Ada.Text_IO.Put_Line (Output, Image_No_Space (Size) & " " & Image_No_Space (Size));
         Ada.Text_IO.Put_Line (Output, "255");
         for Row in 0 .. Size - 1 loop
            for Column in 0 .. Size - 1 loop
               declare
                  Source_Row    : constant Natural := Row * Source_Height / Size;
                  Source_Column : constant Natural := Column * Source_Width / Size;
                  Source_Index  : constant Natural := Source_Row * Source_Width + Source_Column;
                  Pixel         : constant Rgb_Pixel := Pixels.Element (Source_Index);
               begin
                  Ada.Text_IO.Put
                    (Output,
                     Image_No_Space (Pixel.Red) & " "
                     & Image_No_Space (Pixel.Green) & " "
                     & Image_No_Space (Pixel.Blue));
                  if Column < Size - 1 then
                     Ada.Text_IO.Put (Output, " ");
                  end if;
               end;
            end loop;
            Ada.Text_IO.New_Line (Output);
         end loop;
         Ada.Text_IO.Close (Output);
      exception
         when others =>
            Safe_Close (Output);
            raise;
      end Write_Pixels_As_Ppm;

      function Try_Write_Decoded_P3_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         Input  : Ada.Text_IO.File_Type;
         Token  : Unbounded_String;
         Content : Unbounded_String;
         Scan_Index : Positive := 1;
         Pixels : Pixel_Vectors.Vector;
         Source_Width  : Natural := 0;
         Source_Height : Natural := 0;
         Max_Value     : Natural := 0;

         function Next_Token return Boolean is
            Value : Character;
         begin
            Token := Null_Unbounded_String;
            while Scan_Index <= Length (Content) loop
               Value := Element (Content, Scan_Index);
               Scan_Index := Scan_Index + 1;
               if Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
                  if Length (Token) > 0 then
                     return True;
                  end if;
               else
                  Append (Token, Value);
               end if;
            end loop;

            return Length (Token) > 0;
         end Next_Token;

         function Next_Natural
           (Value : out Natural)
            return Boolean is
         begin
            if not Next_Token then
               return False;
            end if;

            Value := Natural'Value (To_String (Token));
            return True;
         exception
            when others =>
               return False;
         end Next_Natural;

         function Scaled_Channel
           (Value : Natural)
            return Natural is
         begin
            if Max_Value = 0 then
               return 0;
            elsif Max_Value = 255 then
               return Natural'Min (Value, 255);
            end if;

            return Natural'Min ((Value * 255) / Max_Value, 255);
         end Scaled_Channel;
      begin
         Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Source_Path);
         while not Ada.Text_IO.End_Of_File (Input) loop
            declare
               Buffer  : String (1 .. 4096);
               Last    : Natural;
               Comment : Natural := 0;
            begin
               Ada.Text_IO.Get_Line (Input, Buffer, Last);
               for Index in 1 .. Last loop
                  if Buffer (Index) = '#' then
                     Comment := Index;
                     exit;
                  end if;
               end loop;

               if Last = 0 then
                  null;
               elsif Comment = 0 then
                  Append (Content, Buffer (1 .. Last));
               elsif Comment > 1 then
                  Append (Content, Buffer (1 .. Comment - 1));
               end if;
               Append (Content, ' ');
            end;
         end loop;
         Ada.Text_IO.Close (Input);

         if not Next_Token or else To_String (Token) /= "P3" then
            return False;
         end if;

         if not Next_Natural (Source_Width)
           or else not Next_Natural (Source_Height)
           or else not Next_Natural (Max_Value)
           or else Source_Width = 0
           or else Source_Height = 0
           or else Max_Value = 0
           or else Source_Width > 4096
           or else Source_Height > 4096
           or else Source_Width * Source_Height > 4_194_304
         then
            return False;
         end if;

         for Pixel_Index in 1 .. Source_Width * Source_Height loop
            declare
               Red   : Natural;
               Green : Natural;
               Blue  : Natural;
            begin
               if not Next_Natural (Red) or else not Next_Natural (Green) or else not Next_Natural (Blue) then
                  return False;
               end if;

               Pixels.Append
                 (New_Item =>
                    Rgb_Pixel'
                      (Red   => Scaled_Channel (Red),
                       Green => Scaled_Channel (Green),
                       Blue  => Scaled_Channel (Blue)));
            end;
         end loop;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Source_Width, Source_Height);
         return True;
      exception
         when others =>
            Safe_Close (Input);
            return False;
      end Try_Write_Decoded_P3_Thumbnail;

      function Try_Write_Decoded_Png_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Last   : Ada.Streams.Stream_Element_Offset;
         Bytes  : Thumbnail_Byte_Vectors.Vector;
         Idat   : Thumbnail_Byte_Vectors.Vector;
         Width  : Natural := 0;
         Height : Natural := 0;
         Bit_Depth  : Natural := 0;
         Color_Type : Natural := 0;
         Interlace  : Natural := 0;
         Position   : Natural := 8;
         Channels   : Natural := 0;
         Pixels     : Pixel_Vectors.Vector;

         function Is_Png_Signature return Boolean is
         begin
            return Natural (Bytes.Length) >= 8
              and then Byte_At (Bytes, 0) = 16#89#
              and then Byte_At (Bytes, 1) = Character'Pos ('P')
              and then Byte_At (Bytes, 2) = Character'Pos ('N')
              and then Byte_At (Bytes, 3) = Character'Pos ('G')
              and then Byte_At (Bytes, 4) = 16#0D#
              and then Byte_At (Bytes, 5) = 16#0A#
              and then Byte_At (Bytes, 6) = 16#1A#
              and then Byte_At (Bytes, 7) = 16#0A#;
         end Is_Png_Signature;

         function Chunk_Type
           (Index : Natural)
            return String is
         begin
            return
              Character'Val (Byte_At (Bytes, Index))
              & Character'Val (Byte_At (Bytes, Index + 1))
              & Character'Val (Byte_At (Bytes, Index + 2))
              & Character'Val (Byte_At (Bytes, Index + 3));
         end Chunk_Type;

         function Raw_Byte
           (Data  : Ada.Streams.Stream_Element_Array;
            Index : Natural)
            return Natural is
         begin
            if Ada.Streams.Stream_Element_Offset (Index) not in Data'Range then
               return 0;
            end if;

            return Natural (Data (Ada.Streams.Stream_Element_Offset (Index)));
         end Raw_Byte;

         function Paeth
           (Left  : Natural;
            Up    : Natural;
            Upper : Natural)
            return Natural
         is
            P  : constant Integer := Integer (Left) + Integer (Up) - Integer (Upper);
            PA : constant Natural := Natural (abs (P - Integer (Left)));
            PB : constant Natural := Natural (abs (P - Integer (Up)));
            PC : constant Natural := Natural (abs (P - Integer (Upper)));
         begin
            if PA <= PB and then PA <= PC then
               return Left;
            elsif PB <= PC then
               return Up;
            else
               return Upper;
            end if;
         end Paeth;
      begin
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Source_Path);
         while not Ada.Streams.Stream_IO.End_Of_File (File) loop
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            for Index in 1 .. Last loop
               Bytes.Append (Buffer (Index));
            end loop;
         end loop;
         Ada.Streams.Stream_IO.Close (File);

         if not Is_Png_Signature then
            return False;
         end if;

         while Position + 12 <= Natural (Bytes.Length) loop
            declare
               Length_Value : constant Natural := U32_BE_From (Bytes, Position);
               Kind         : constant String := Chunk_Type (Position + 4);
               Data_Start   : constant Natural := Position + 8;
               Data_Last    : constant Natural := Data_Start + Length_Value - 1;
            begin
               if Data_Start + Length_Value + 4 > Natural (Bytes.Length) then
                  return False;
               end if;

               if Kind = "IHDR" then
                  if Length_Value < 13 then
                     return False;
                  end if;
                  Width := U32_BE_From (Bytes, Data_Start);
                  Height := U32_BE_From (Bytes, Data_Start + 4);
                  Bit_Depth := Byte_At (Bytes, Data_Start + 8);
                  Color_Type := Byte_At (Bytes, Data_Start + 9);
                  Interlace := Byte_At (Bytes, Data_Start + 12);
               elsif Kind = "IDAT" then
                  if Length_Value > 0 then
                     for Index in Data_Start .. Data_Last loop
                        Idat.Append (Bytes.Element (Index));
                     end loop;
                  end if;
               elsif Kind = "IEND" then
                  exit;
               end if;

               Position := Data_Start + Length_Value + 4;
            end;
         end loop;

         if Width = 0
           or else Height = 0
           or else Width > 4096
           or else Height > 4096
           or else Width * Height > 4_194_304
           or else Bit_Depth /= 8
           or else Interlace /= 0
           or else Idat.Is_Empty
         then
            --  Adam7-interlaced PNGs have a different IDAT layout than the
            --  single raster this decoder assumes; defer to the gdk-pixbuf
            --  fallback rather than producing a garbled thumbnail.
            return False;
         elsif Color_Type = 2 then
            Channels := 3;
         elsif Color_Type = 6 then
            Channels := 4;
         else
            return False;
         end if;

         declare
            Row_Stride : constant Natural := Width * Channels;
            Needed     : constant Natural := Height * (Row_Stride + 1);
            Compressed : constant Ada.Streams.Stream_Element_Array := Bytes_To_Stream_Array (Idat);
            Source     : Zlib.Byte_Array (0 .. Natural (Compressed'Length) - 1);
            Inflated   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Needed - 1)) :=
              [others => 0];
            Decode_Status : Zlib.Status_Code := Zlib.Ok;
            Previous   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
            Current    : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
         begin
            for I in Source'Range loop
               Source (I) :=
                 Zlib.Byte (Compressed (Compressed'First + Ada.Streams.Stream_Element_Offset (I)));
            end loop;
            --  Inflate the zlib-wrapped PNG IDAT stream with the pure-Ada zlib
            --  crate (no system libz dependency).
            declare
               use type Zlib.Status_Code;
               Raw_Inflated : constant Zlib.Byte_Array :=
                 Zlib.Inflate_With_Header (Source, Zlib.Zlib_Header, Decode_Status);
            begin
               if Decode_Status /= Zlib.Ok or else Raw_Inflated'Length < Needed then
                  return False;
               end if;
               for I in 0 .. Needed - 1 loop
                  Inflated (Ada.Streams.Stream_Element_Offset (I)) :=
                    Ada.Streams.Stream_Element (Raw_Inflated (Raw_Inflated'First + I));
               end loop;
            end;

            for Row in 0 .. Height - 1 loop
               declare
                  Filter : constant Natural := Raw_Byte (Inflated, Row * (Row_Stride + 1));
                  Base   : constant Natural := Row * (Row_Stride + 1) + 1;
               begin
                  if Filter > 4 then
                     return False;
                  end if;

                  for Column in 0 .. Row_Stride - 1 loop
                     declare
                        Raw   : constant Natural := Raw_Byte (Inflated, Base + Column);
                        Left  : constant Natural :=
                          (if Column >= Channels
                           then Natural (Current (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                           else 0);
                        Up    : constant Natural :=
                          Natural (Previous (Ada.Streams.Stream_Element_Offset (Column)));
                        Upper : constant Natural :=
                          (if Column >= Channels
                           then Natural (Previous (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                           else 0);
                        Value : Natural := Raw;
                     begin
                        case Filter is
                           when 0 =>
                              null;
                           when 1 =>
                              Value := Raw + Left;
                           when 2 =>
                              Value := Raw + Up;
                           when 3 =>
                              Value := Raw + (Left + Up) / 2;
                           when 4 =>
                              Value := Raw + Paeth (Left, Up, Upper);
                           when others =>
                              null;
                        end case;
                        Current (Ada.Streams.Stream_Element_Offset (Column)) :=
                          Ada.Streams.Stream_Element (Value mod 256);
                     end;
                  end loop;

                  for Column in 0 .. Width - 1 loop
                     Pixels.Append
                       (Rgb_Pixel'
                          (Red   =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels))),
                           Green =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 1))),
                           Blue  =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 2)))));
                  end loop;

                  Previous := Current;
               end;
            end loop;
         end;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Width, Height);
         return True;
      exception
         when others =>
            Safe_Close (File);
            return False;
      end Try_Write_Decoded_Png_Thumbnail;

      function Try_Write_Gdk_Pixbuf_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Source_Path);
         Pixbuf : System.Address := System.Null_Address;
      begin
         Pixbuf :=
           Gdk_Pixbuf_New_From_File_At_Size
             (Filename => C_Path,
              Width    => C_Int (Size),
              Height   => C_Int (Size),
              Error    => System.Null_Address);
         Interfaces.C.Strings.Free (C_Path);

         if Pixbuf = System.Null_Address then
            return False;
         end if;

         declare
            Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
            Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
            Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
            Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
            Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
            Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
              Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
            Decoded   : Pixel_Vectors.Vector;
         begin
            if Width = 0
              or else Height = 0
              or else Width > 4096
              or else Height > 4096
              or else Channels < 3
              or else Rowstride < Width * Channels
              or else Pixels_Address = System.Null_Address
              or else Raw = null
            then
               G_Object_Unref (Pixbuf);
               return False;
            end if;

            for Row in 0 .. Height - 1 loop
               for Column in 0 .. Width - 1 loop
                  declare
                     Offset : constant Natural := Row * Rowstride + Column * Channels;
                  begin
                     Decoded.Append
                       (Rgb_Pixel'
                          (Red   => Natural (Raw.all (Offset)),
                           Green => Natural (Raw.all (Offset + 1)),
                           Blue  => Natural (Raw.all (Offset + 2))));
                  end;
               end loop;
            end loop;

            G_Object_Unref (Pixbuf);
            Pixbuf := System.Null_Address;
            --  Null the handle before any further work: Write_Pixels_As_Ppm can
            --  raise, and the exception handler unrefs Pixbuf when non-null.
            Write_Pixels_As_Ppm (Target_Path, Decoded, Width, Height);
            return True;
         end;
      exception
         when others =>
            Safe_Free (C_Path);
            if Pixbuf /= System.Null_Address then
               G_Object_Unref (Pixbuf);
            end if;
            return False;
      end Try_Write_Gdk_Pixbuf_Thumbnail;

      Checksum  : Natural := 0;
      Size_Bias : Natural := 0;
      Target    : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Source_Path) then
         return
           (Status         => Thumbnail_Source_Missing,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.source_missing"));
      elsif Ada.Directories.Kind (Source_Path) /= Ada.Directories.Ordinary_File then
         return
           (Status         => Thumbnail_Unsupported,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.unsupported"));
      end if;

      Ada.Directories.Create_Path (Cache_Directory);
      Target := To_Unbounded_String (Thumbnail_Path_For (Source_Path, Cache_Directory, Size));
      if Try_Write_Decoded_Png_Thumbnail (To_String (Target))
        or else Try_Write_Decoded_P3_Thumbnail (To_String (Target))
        or else Try_Write_Gdk_Pixbuf_Thumbnail (To_String (Target))
      then
         return
           (Status         => Thumbnail_Generated,
            Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => Null_Unbounded_String);
      end if;

      Checksum := Thumbnail_Path_Checksum (Source_Path);
      Size_Bias := File_Size_Signal;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Target));
      Ada.Text_IO.Put_Line (File, "P3");
      Ada.Text_IO.Put_Line (File, Image_No_Space (Size) & " " & Image_No_Space (Size));
      Ada.Text_IO.Put_Line (File, "255");
      for Row in 0 .. Size - 1 loop
         for Column in 0 .. Size - 1 loop
            declare
               Cell   : constant Natural := Natural'Max (1, Size / 8);
               Stripe : constant Natural := (Row / Cell + Column / Cell) mod 2;
               Red    : constant Natural := Clamp_Channel (Checksum + Row * 5 + Size_Bias / 7 + Stripe * 28);
               Green  : constant Natural := Clamp_Channel (Checksum / 257 + Column * 7 + Size_Bias / 11);
               Blue   : constant Natural := Clamp_Channel (Checksum / 65_521 + Row + Column * 3 + Size_Bias / 13);
            begin
               Ada.Text_IO.Put
                 (File,
                  Image_No_Space (Red) & " "
                  & Image_No_Space (Green) & " "
                  & Image_No_Space (Blue));
               if Column < Size - 1 then
                  Ada.Text_IO.Put (File, " ");
               end if;
            end;
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);

      return
        (Status         => Thumbnail_Generated,
         Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
         Thumbnail_Path => Target,
         Width          => Size,
         Height         => Size,
         Error_Key      => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         return
           (Status         => Thumbnail_Failed,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.failed"));
   end Generate_Thumbnail;

end Files.File_System;
