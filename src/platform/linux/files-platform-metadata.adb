with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;

package body Files.Platform.Metadata is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.unsigned_short;
   use type Interfaces.C.Strings.chars_ptr;

   subtype C_Int is Interfaces.C.int;
   subtype C_Unsigned is Interfaces.C.unsigned;
   subtype C_U16 is Interfaces.C.unsigned_short;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;
   subtype C_Size is Interfaces.C.size_t;
   subtype C_ULong is Interfaces.C.unsigned_long;
   subtype C_Char is Interfaces.C.char;

   At_FDCWD : constant C_Int := -100;
   At_Symlink_Nofollow : constant C_Unsigned := 16#100#;
   Statx_Btime : constant C_Unsigned := 16#800#;
   Statvfs_Read_Only : constant C_ULong := 1;

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

   function Symlink
     (Target   : Interfaces.C.Strings.chars_ptr;
      Link_Path : Interfaces.C.Strings.chars_ptr)
      return C_Int
     with Import, Convention => C, External_Name => "symlink";

   function Link
     (Existing_Path : Interfaces.C.Strings.chars_ptr;
      New_Path      : Interfaces.C.Strings.chars_ptr)
      return C_Int
     with Import, Convention => C, External_Name => "link";

   function Chmod
     (Pathname : Interfaces.C.Strings.chars_ptr;
      Mode     : C_Unsigned)
      return C_Int
     with Import, Convention => C, External_Name => "chmod";

   Statx_Mode      : constant C_Unsigned := 16#2#;
   Permission_Mask : constant C_U16 := 8#7777#;

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

   function File_Creation_Time
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
   end File_Creation_Time;

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

   function Volume_Capacity_Of (Path : String) return Volume_Capacity is
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
      Result : Volume_Capacity;
   begin
      Status := Statvfs (C_Path, Data'Access);
      Interfaces.C.Strings.Free (C_Path);
      if Status = 0 then
         Result.Read_Only := (Data.Flags and Statvfs_Read_Only) /= 0;
         Result.Read_Only_Known := True;
         if Data.Name_Max > 0 then
            Result.Name_Max := Saturating_Natural (Data.Name_Max);
            Result.Name_Max_Known := True;
         end if;
         if Data.Files > 0 then
            Result.Inode_Count := Saturating_Long_Long (Data.Files);
            Result.Free_Inode_Count := Saturating_Long_Long (Data.Files_Free);
            Result.Inodes_Known := True;
         end if;
         if Data.Fragment_Size > 0 and then Data.Blocks > 0 then
            Result.Capacity_Bytes := Saturating_Byte_Count (Data.Blocks, Data.Fragment_Size);
            Result.Free_Bytes := Saturating_Byte_Count (Data.Blocks_Available, Data.Fragment_Size);
            Result.Available := True;
         end if;
      end if;
      return Result;
   exception
      when others =>
         Safe_Free (C_Path);
         return (others => <>);
   end Volume_Capacity_Of;

   function Create_Symbolic_Link
     (Target    : String;
      Link_Path : String)
      return Boolean
   is
      C_Target : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Target);
      C_Link   : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Link_Path);
      Status   : C_Int;
   begin
      Status := Symlink (C_Target, C_Link);
      Interfaces.C.Strings.Free (C_Target);
      Interfaces.C.Strings.Free (C_Link);
      return Status = 0;
   exception
      when others =>
         Safe_Free (C_Target);
         Safe_Free (C_Link);
         return False;
   end Create_Symbolic_Link;

   function Create_Hard_Link
     (Existing_Path : String;
      New_Path      : String)
      return Boolean
   is
      C_Existing : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Existing_Path);
      C_New      : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (New_Path);
      Status     : C_Int;
   begin
      Status := Link (C_Existing, C_New);
      Interfaces.C.Strings.Free (C_Existing);
      Interfaces.C.Strings.Free (C_New);
      return Status = 0;
   exception
      when others =>
         Safe_Free (C_Existing);
         Safe_Free (C_New);
         return False;
   end Create_Hard_Link;

   function File_Permission_Bits
     (Path      : String;
      Available : out Boolean)
      return Natural
   is
      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Info   : aliased Statx_Record;
      Status : C_Int;
   begin
      Available := False;
      Status := Statx (At_FDCWD, C_Path, 0, Statx_Mode, Info'Access);
      Interfaces.C.Strings.Free (C_Path);

      if Status = 0 then
         Available := True;
         return Natural (Info.Mode and Permission_Mask);
      end if;

      return 0;
   exception
      when others =>
         Safe_Free (C_Path);
         Available := False;
         return 0;
   end File_Permission_Bits;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Boolean
   is
      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Status : C_Int;
   begin
      Status := Chmod (C_Path, C_Unsigned (Mode mod 8#10000#));
      Interfaces.C.Strings.Free (C_Path);
      return Status = 0;
   exception
      when others =>
         Safe_Free (C_Path);
         return False;
   end Set_Permissions;

   function Permissions_Supported return Boolean is
   begin
      return True;
   end Permissions_Supported;

end Files.Platform.Metadata;
