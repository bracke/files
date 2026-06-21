with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Interfaces.C;
with Interfaces.C.Strings;

with GNAT.OS_Lib;

with Files.File_Types;
with Files.Platform.Macos;
with Files.Platform.Windows;

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
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;

   subtype C_Int is Interfaces.C.int;
   subtype C_Unsigned is Interfaces.C.unsigned;
   subtype C_U16 is Interfaces.C.unsigned_short;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;
   subtype C_Size is Interfaces.C.size_t;
   subtype C_Char is Interfaces.C.char;
   subtype C_ULong is Interfaces.C.unsigned_long;

   At_FDCWD : constant C_Int := -100;
   At_Symlink_Nofollow : constant C_Unsigned := 16#100#;
   Statx_Btime : constant C_Unsigned := 16#800#;
   Statvfs_Read_Only : constant C_ULong := 1;
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

   type U16_Array is array (Positive range <>) of C_U16
     with Convention => C;

   type U64_Array is array (Positive range <>) of C_U64
     with Convention => C;

   type Statx_Timestamp is record
      Seconds     : C_S64;
      Nanoseconds : C_U32;
      Reserved    : C_U32;
   end record
     with Convention => C;

   type Statx_Record is record
      Mask            : C_U32;
      Block_Size      : C_U32;
      Attributes      : C_U64;
      Link_Count      : C_U32;
      User_Id         : C_U32;
      Group_Id        : C_U32;
      Mode            : C_U16;
      Spare_0         : U16_Array (1 .. 1);
      Inode           : C_U64;
      Size            : C_U64;
      Blocks          : C_U64;
      Attributes_Mask : C_U64;
      Access_Time     : Statx_Timestamp;
      Birth_Time      : Statx_Timestamp;
      Change_Time     : Statx_Timestamp;
      Modified_Time   : Statx_Timestamp;
      Device_Major    : C_U32;
      Device_Minor    : C_U32;
      File_Major      : C_U32;
      File_Minor      : C_U32;
      Mount_Id        : C_U64;
      Direct_Io_Memory_Align : C_U32;
      Direct_Io_Offset_Align : C_U32;
      Spare_3         : U64_Array (1 .. 12);
   end record
     with Convention => C;

   type Statvfs_Record is record
      Block_Size             : C_ULong;
      Fragment_Size          : C_ULong;
      Blocks                 : C_ULong;
      Blocks_Free            : C_ULong;
      Blocks_Available       : C_ULong;
      Files                  : C_ULong;
      Files_Free             : C_ULong;
      Files_Available        : C_ULong;
      Filesystem_Id          : C_ULong;
      Flags                  : C_ULong;
      Name_Max               : C_ULong;
      Spare                  : U64_Array (1 .. 6);
   end record
     with Convention => C;

   function Statx
     (Directory_Fd : C_Int;
      Pathname     : Interfaces.C.Strings.chars_ptr;
      Flags        : C_Unsigned;
      Mask         : C_Unsigned;
      Buffer       : access Statx_Record)
      return C_Int
     with Import, Convention => C, External_Name => "statx";

   function Readlink
     (Pathname : Interfaces.C.Strings.chars_ptr;
      Buffer   : out Interfaces.C.char_array;
      Bufsiz   : C_Size)
      return C_S64
     with Import, Convention => C, External_Name => "readlink";

   function Statvfs
     (Pathname : Interfaces.C.Strings.chars_ptr;
      Buffer   : access Statvfs_Record)
      return C_Int
     with Import, Convention => C, External_Name => "statvfs";

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
     (Left     : Directory_Item;
      Right    : Directory_Item;
      Settings : Files.Settings.Settings_Model)
      return Boolean
   is
      Forward_Order : Boolean := False;
      Reverse_Order : Boolean := False;
   begin
      case Settings.Sort_Field_Value is
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
         when Files.Settings.Sort_By_Modified =>
            if Left.Modified_Available /= Right.Modified_Available then
               return Left.Modified_Available;
            elsif Left.Modified_Time /= Right.Modified_Time then
               Forward_Order := Left.Modified_Time < Right.Modified_Time;
               Reverse_Order := Right.Modified_Time < Left.Modified_Time;
            end if;
      end case;

      if Settings.Sort_Field_Value /= Files.Settings.Sort_By_Name
        and then not Forward_Order
        and then not Reverse_Order
      then
         return Name_Less (Left, Right);
      elsif Settings.Sort_Ascending then
         return Forward_Order;
      else
         return Reverse_Order;
      end if;
   end Field_Less;

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

   function Creation_Time_For
     (Path      : String;
      Available : out Boolean)
      return Ada.Calendar.Time
   is
      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Info   : aliased Statx_Record;
      Status : C_Int;
      Epoch  : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1);
   begin
      Available := False;
      Status := Statx (At_FDCWD, C_Path, At_Symlink_Nofollow, Statx_Btime, Info'Access);
      Interfaces.C.Strings.Free (C_Path);

      if Status = 0 and then (Info.Mask and Statx_Btime) /= 0 and then Info.Birth_Time.Seconds >= 0 then
         Available := True;
         return Epoch + Duration (Info.Birth_Time.Seconds) + Duration (Info.Birth_Time.Nanoseconds) / 1_000_000_000.0;
      end if;

      return Ada.Calendar.Time_Of (1901, 1, 1);
   exception
      when others =>
         Safe_Free (C_Path);
         Available := False;
         return Ada.Calendar.Time_Of (1901, 1, 1);
   end Creation_Time_For;

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
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
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

   function Symlink_Target_Token (Path : String) return String is
      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Buffer : Interfaces.C.char_array (0 .. 4095);
      Count  : C_S64;
      Target : Unbounded_String := Null_Unbounded_String;
   begin
      Count := Readlink (C_Path, Buffer, Buffer'Length);
      Interfaces.C.Strings.Free (C_Path);
      if Count <= 0 then
         return "";
      end if;

      for Index in 0 .. Integer (Count) - 1 loop
         Append (Target, Character'Val (C_Char'Pos (Buffer (Interfaces.C.size_t (Index)))));
      end loop;

      return "symlink.target|" & To_String (Target);
   exception
      when others =>
         Safe_Free (C_Path);
         return "";
   end Symlink_Target_Token;

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
            return Symlink_Target_Token (Path);
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
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
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
                  Full     : constant String := Ada.Directories.Full_Name (Dir_Entry);
                  Kind     : constant Files.Types.Item_Kind := Kind_From_Directory_Entry (Dir_Entry);
                  Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
                  Item     : Directory_Item :=
                    (Name               => To_Unbounded_String (Name),
                     Full_Path          => To_Unbounded_String (Full),
                     Parent_Path        => Normalized_Path,
                     Kind               => Kind,
                     Filetype           => To_Unbounded_String (Filetype),
                     Icon_Id            =>
                       To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Filetype)),
                     Size_Available     => False,
                     Size               => 0,
                     Creation_Available => False,
                     Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Modified_Available => False,
                     Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
                     Permissions        => Null_Unbounded_String,
                     Filetype_Extra     => Null_Unbounded_String,
                     Metadata_Error     => False,
                     Error_Key          => Null_Unbounded_String);
               begin
                  if Kind = Files.Types.Symlink_Item then
                     Item.Filetype_Extra :=
                       To_Unbounded_String (Extra_Info_Token (Full, Kind, Filetype));
                  end if;

                  begin
                     if Kind /= Files.Types.Directory_Item then
                        Item.Size := Long_Long_Integer (Ada.Directories.Size (Full));
                        Item.Size_Available := True;
                     end if;
                     Item.Creation_Time := Creation_Time_For (Full, Item.Creation_Available);
                     Item.Modified_Time := Ada.Directories.Modification_Time (Full);
                     Item.Modified_Available := True;
                     Item.Permissions := To_Unbounded_String (Permission_String (Full));
                     if Kind /= Files.Types.Symlink_Item then
                        Item.Filetype_Extra :=
                          To_Unbounded_String (Extra_Info_Token (Full, Kind, Filetype));
                     end if;
                  exception
                     when others =>
                        Item.Metadata_Error := True;
                        Item.Error_Key := To_Unbounded_String ("error.metadata.read");
                  end;

                  Items.Append (Item);
               end;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);

      declare
         function Less (Left : Directory_Item; Right : Directory_Item) return Boolean is
         begin
            if Settings.Sort_Directories_First and then Is_Directory (Left) /= Is_Directory (Right) then
               return Is_Directory (Left);
            end if;

            return Field_Less (Left, Right, Settings);
         end Less;

         package Sorting is new Item_Vectors.Generic_Sorting ("<" => Less);
      begin
         Sorting.Sort (Items);
      end;

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
         when Root_Windows_Drive =>
            return "root.drive|" & Path;
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

      function Filesystem_Type_For (Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Buffer : String (1 .. 4096);
         Last   : Natural;

         function Field
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
         end Field;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return "";
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Line        : constant String := Buffer (1 .. Last);
               Mount_Point : constant String := Field (Line, 2);
            begin
               if Mount_Point = Path then
                  Ada.Text_IO.Close (File);
                  return Field (Line, 3);
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
      begin
         if Ada.Directories.Exists (Path)
           and then Ada.Directories.Kind (Path) = Ada.Directories.Directory
         then
            Full := To_Unbounded_String (Ada.Directories.Full_Name (Path));
            Name := To_Unbounded_String (Ada.Directories.Simple_Name (To_String (Full)));
            if Length (Name) = 0 then
               Name := Full;
            end if;
            Label := To_Unbounded_String (Root_Label (To_String (Full), Kind));
            if Kind in Root_Mount | Root_User_Mount | Root_Filesystem then
               declare
                  Filesystem_Type : constant String := Filesystem_Type_For (To_String (Full));
               begin
                  if Filesystem_Type /= "" and then Ada.Strings.Fixed.Index (To_String (Label), "|") > 0 then
                     Append (Label, "|");
                     Append (Label, Filesystem_Type);
                  end if;
               end;
            end if;
            if not Contains_Root (To_String (Full)) then
               Roots.Append
                 (Root_Entry'
                    (Path  => Full,
                     Label => Label,
                     Kind  => Kind,
                     Volume_Name => Name,
                     Ready => Root_Ready,
                     Removable => Kind = Root_Mount or else Kind = Root_User_Mount));
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
            begin
               if Name /= "." and then Name /= ".." then
                  Append_If_Directory (Ada.Directories.Full_Name (Child), Kind);
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

         function Mount_Point_From (Line : String) return String is
            First_Space  : Natural := 0;
            Second_Start : Natural := 0;
            Second_End   : Natural := 0;
         begin
            for Index in Line'Range loop
               if Line (Index) = ' ' then
                  First_Space := Index;
                  exit;
               end if;
            end loop;

            if First_Space = 0 or else First_Space = Line'Last then
               return "";
            end if;

            Second_Start := First_Space + 1;
            while Second_Start <= Line'Last and then Line (Second_Start) = ' ' loop
               Second_Start := Second_Start + 1;
            end loop;

            Second_End := Second_Start;
            while Second_End <= Line'Last and then Line (Second_End) /= ' ' loop
               Second_End := Second_End + 1;
            end loop;

            if Second_Start > Line'Last or else Second_End <= Second_Start then
               return "";
            end if;

            return Decode_Mount_Escapes (Line (Second_Start .. Second_End - 1));
         end Mount_Point_From;
      begin
         if not Ada.Directories.Exists ("/proc/mounts") then
            return;
         end if;

         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
         while not Ada.Text_IO.End_Of_File (File) loop
            Ada.Text_IO.Get_Line (File, Buffer, Last);
            declare
               Mount_Point : constant String := Mount_Point_From (Buffer (1 .. Last));
            begin
               if Mount_Point /= ""
                 and then Mount_Point /= "/proc"
                 and then Mount_Point /= "/sys"
                 and then Mount_Point /= "/dev"
               then
                  Append_If_Directory (Mount_Point, Root_Mount);
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
         Append_Children (Join_Path (Xdg_Runtime_Dir, "gvfs"), Root_User_Mount);
      end if;
      if User_Name /= "" then
         declare
            Run_Media_User : constant String := "/run/media/" & User_Name;
         begin
            Append_If_Directory (Run_Media_User, Root_User_Mount);
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
         Append_If_Directory (Home_Share, Root_User_Mount);
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
      Has_Statvfs     : Boolean := False;

      function Statvfs_Available return Boolean is
         C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String ("/");
         Info   : aliased Statvfs_Record;
         Status : C_Int;
      begin
         Status := Statvfs (C_Path, Info'Access);
         Interfaces.C.Strings.Free (C_Path);
         return Status = 0 and then Info.Fragment_Size > 0 and then Info.Blocks > 0;
      exception
         when others =>
            Safe_Free (C_Path);
            return False;
      end Statvfs_Available;
   begin
      Has_Statvfs := Statvfs_Available;
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
      function Saturating_Natural (Value : C_ULong) return Natural is
      begin
         if Value > C_ULong (Natural'Last) then
            return Natural'Last;
         else
            return Natural (Value);
         end if;
      end Saturating_Natural;

      function Saturating_Long_Long (Value : C_ULong) return Long_Long_Integer is
      begin
         if Value > C_ULong (Long_Long_Integer'Last) then
            return Long_Long_Integer'Last;
         else
            return Long_Long_Integer (Value);
         end if;
      end Saturating_Long_Long;

      function Saturating_Byte_Count
        (Blocks        : C_ULong;
         Fragment_Size : C_ULong)
         return Long_Long_Integer
      is
         Block_Count : constant Long_Long_Integer := Saturating_Long_Long (Blocks);
         Unit_Size   : constant Long_Long_Integer := Saturating_Long_Long (Fragment_Size);
      begin
         if Block_Count = 0 or else Unit_Size = 0 then
            return 0;
         elsif Block_Count > Long_Long_Integer'Last / Unit_Size then
            return Long_Long_Integer'Last;
         else
            return Block_Count * Unit_Size;
         end if;
      end Saturating_Byte_Count;

      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Data   : aliased Statvfs_Record;
      Status : C_Int;
   begin
      Info := (others => <>);
      Status := Statvfs (C_Path, Data'Access);
      Interfaces.C.Strings.Free (C_Path);
      if Status = 0 then
         Info.Read_Only := (Data.Flags and Statvfs_Read_Only) /= 0;
         Info.Read_Only_Known := True;
         if Data.Name_Max > 0 then
            Info.Name_Max := Saturating_Natural (Data.Name_Max);
            Info.Name_Max_Known := True;
         end if;
         if Data.Files > 0 then
            Info.Inode_Count := Saturating_Long_Long (Data.Files);
            Info.Free_Inode_Count := Saturating_Long_Long (Data.Files_Free);
            Info.Inodes_Known := True;
         end if;
         if Data.Fragment_Size > 0 and then Data.Blocks > 0 then
            Info.Capacity_Bytes := Saturating_Byte_Count (Data.Blocks, Data.Fragment_Size);
            Info.Free_Bytes := Saturating_Byte_Count (Data.Blocks_Available, Data.Fragment_Size);
            Info.Known := True;
         end if;
      end if;
   exception
      when others =>
         Safe_Free (C_Path);
         Info := (others => <>);
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
   begin
      if Queryable then
         Volume_Size_For (Path_Text, Volume);
      end if;

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
         Uses_Platform_Detail =>
           Volume.Known
           or else Volume.Inodes_Known
           or else Volume.Read_Only_Known
           or else Volume.Name_Max_Known
           or else Mount.Found
           or else Mount.Removable_Known);
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
         Filetype_Extra     => Null_Unbounded_String,
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
         Filetype_Extra     => Null_Unbounded_String,
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

   function Create_Empty_File
     (Path : String)
      return Mutation_Result
   is
      File    : Ada.Text_IO.File_Type;
      Created : Boolean := False;

      procedure Delete_Created_File_If_Present is
      begin
         if Created and then Ada.Directories.Exists (Path) then
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
   begin
      if Path = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.file.parent_missing"));
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

   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result
   is
      function Exists_Safely (Path : String) return Boolean is
      begin
         return Path /= "" and then Ada.Directories.Exists (Path);
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
   begin
      if not Exists_Safely (From_Path) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.rename.source_missing"));
      elsif Same_Existing_Path then
         return (Success => True, Error_Key => Null_Unbounded_String);
      elsif To_Path = ""
        or else Exists_Safely (To_Path)
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

   function Move_To_Trash
     (Path : String)
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
           or else Ada.Directories.Exists (Join_Path (Info_Directory, To_String (Candidate) & ".trashinfo"))
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

      Base      : constant String := Trash_Base_Path;
      Files_Dir : constant String := (if Base = "" then "" else Join_Path (Base, "files"));
      Info_Dir  : constant String := (if Base = "" then "" else Join_Path (Base, "info"));
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
      declare
         Preflight : constant Mutation_Result := Move_To_Trash_Preflight (Path);
      begin
         if not Preflight.Success then
            return Preflight;
         end if;
      end;

      Ada.Directories.Create_Path (Files_Dir);
      Ada.Directories.Create_Path (Info_Dir);

      Name := To_Unbounded_String
        (Unique_Trash_Name (Files_Dir, Info_Dir, Ada.Directories.Simple_Name (Path)));
      Target := To_Unbounded_String (Join_Path (Files_Dir, To_String (Name)));
      Info_Path := To_Unbounded_String (Join_Path (Info_Dir, To_String (Name) & ".trashinfo"));

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Info_Path));
      Ada.Text_IO.Put_Line (File, "[Trash Info]");
      Ada.Text_IO.Put_Line (File, "Path=" & Trash_Info_Path_Value (Ada.Directories.Full_Name (Path)));
      Ada.Text_IO.Put_Line (File, "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock));
      Ada.Text_IO.Close (File);

      begin
         Ada.Directories.Rename (Path, To_String (Target));
      exception
         when others =>
            Delete_Info_File_If_Present;
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.failed"));
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

end Files.File_System;
