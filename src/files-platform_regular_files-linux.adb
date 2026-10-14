with Interfaces.C;
with Interfaces.C.Strings;

package body Files.Platform_Regular_Files is
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_short;
   use type Interfaces.C.Strings.chars_ptr;

   subtype C_Int is Interfaces.C.int;
   subtype C_U16 is Interfaces.C.unsigned_short;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;

   O_Nonblock : constant C_Int := 16#800#;
   O_Nofollow : constant C_Int := 16#2_0000#;
   O_Cloexec  : constant C_Int := 16#8_0000#;
   O_Noatime  : constant C_Int := 16#4_0000#;
   At_Empty_Path : constant C_Int := 16#1000#;
   Statx_Mode : constant C_U32 := 16#2#;
   File_Type_Mask : constant C_U16 := 8#170000#;
   Regular_File   : constant C_U16 := 8#100000#;

   type U16_Array is array (Positive range <>) of C_U16 with Convention => C;
   type U64_Array is array (Positive range <>) of C_U64 with Convention => C;
   type Statx_Timestamp is record
      Seconds     : C_S64;
      Nanoseconds : C_U32;
      Reserved    : C_U32;
   end record with Convention => C;
   type Statx_Record is record
      Mask                   : C_U32;
      Block_Size             : C_U32;
      Attributes             : C_U64;
      Link_Count             : C_U32;
      User_Id                : C_U32;
      Group_Id               : C_U32;
      Mode                   : C_U16;
      Spare_0                : U16_Array (1 .. 1);
      Inode                  : C_U64;
      Size                   : C_U64;
      Blocks                 : C_U64;
      Attributes_Mask        : C_U64;
      Access_Time            : Statx_Timestamp;
      Birth_Time             : Statx_Timestamp;
      Change_Time            : Statx_Timestamp;
      Modified_Time          : Statx_Timestamp;
      Special_Device_Major   : C_U32;
      Special_Device_Minor   : C_U32;
      Device_Major           : C_U32;
      Device_Minor           : C_U32;
      Mount_Id               : C_U64;
      Direct_Io_Memory_Align : C_U32;
      Direct_Io_Offset_Align : C_U32;
      Spare_3                : U64_Array (1 .. 12);
   end record with Convention => C;

   function C_Open (Path : Interfaces.C.Strings.chars_ptr; Flags : C_Int) return C_Int
     with Import, Convention => C, External_Name => "open";
   function C_Statx
     (Descriptor : C_Int;
      Path       : Interfaces.C.Strings.chars_ptr;
      Flags      : C_Int;
      Mask       : C_U32;
      Info       : access Statx_Record) return C_Int
     with Import, Convention => C, External_Name => "statx";
   function C_Lseek (Descriptor : C_Int; Offset : C_S64; Origin : C_Int) return C_S64
     with Import, Convention => C, External_Name => "lseek";
   function C_Truncate (Descriptor : C_Int; Length : C_S64) return C_Int
     with Import, Convention => C, External_Name => "ftruncate";

   function Open_Read
     (Path         : String;
      Follow_Links : Boolean;
      Supported    : out Boolean) return GNAT.OS_Lib.File_Descriptor
   is
      Name  : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Empty : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Flags : C_Int := O_Nonblock + O_Cloexec;
      Result : C_Int := -1;
      Info   : aliased Statx_Record;
   begin
      Supported := True;
      Name := Interfaces.C.Strings.New_String (Path);
      Empty := Interfaces.C.Strings.New_String ("");
      if not Follow_Links then
         Flags := Flags + O_Nofollow;
      end if;
      Result := C_Open (Name, Flags + O_Noatime);
      if Result < 0 and then GNAT.OS_Lib.Errno in 1 | 22 | 95 then
         Result := C_Open (Name, Flags);
      end if;
      Interfaces.C.Strings.Free (Name);
      if Result < 0
        or else C_Statx (Result, Empty, At_Empty_Path, Statx_Mode, Info'Access) /= 0
        or else (Info.Mask and Statx_Mode) = 0
        or else (Info.Mode and File_Type_Mask) /= Regular_File
      then
         if Result >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Result));
         end if;
         Interfaces.C.Strings.Free (Empty);
         return GNAT.OS_Lib.Invalid_FD;
      end if;
      Interfaces.C.Strings.Free (Empty);
      return GNAT.OS_Lib.File_Descriptor (Result);
   exception
      when others =>
         if Result >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Result));
         end if;
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         if Empty /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Empty);
         end if;
         return GNAT.OS_Lib.Invalid_FD;
   end Open_Read;

   function Skip_Zeros
     (Descriptor : GNAT.OS_Lib.File_Descriptor;
      Count      : Integer) return Boolean is
     (C_Lseek (C_Int (Descriptor), C_S64 (Count), 1) >= 0);

   function Finish_Sparse (Descriptor : GNAT.OS_Lib.File_Descriptor) return Boolean is
      Position : constant C_S64 := C_Lseek (C_Int (Descriptor), 0, 1);
   begin
      return Position >= 0 and then C_Truncate (C_Int (Descriptor), Position) = 0;
   end Finish_Sparse;
end Files.Platform_Regular_Files;
