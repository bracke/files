with Interfaces.C;
with Interfaces.C.Strings;

package body Files.Platform_Regular_Files is
   use type Interfaces.C.int;
   use type Interfaces.C.long_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.C.unsigned_short;

   subtype C_Int is Interfaces.C.int;
   subtype C_U16 is Interfaces.C.unsigned_short;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S32 is Interfaces.C.int;
   subtype C_S64 is Interfaces.C.long;
   subtype File_Offset is Interfaces.C.long_long;

   O_Nonblock : constant C_Int := 16#4#;
   O_Nofollow : constant C_Int := 16#100#;
   O_Cloexec  : constant C_Int := 16#100_0000#;
   File_Type_Mask : constant C_U16 := 8#170000#;
   Regular_File   : constant C_U16 := 8#100000#;

   type Timespec is record
      Seconds     : C_S64 := 0;
      Nanoseconds : C_S64 := 0;
   end record with Convention => C;
   type Spare_Array is array (1 .. 2) of C_S64 with Convention => C;
   type Stat_Record is record
      Device        : C_S32 := 0;
      Mode          : C_U16 := 0;
      Link_Count    : C_U16 := 0;
      Inode         : C_U64 := 0;
      User_Id       : C_U32 := 0;
      Group_Id      : C_U32 := 0;
      Raw_Device    : C_S32 := 0;
      Padding       : C_S32 := 0;
      Access_Time   : Timespec;
      Modified_Time : Timespec;
      Change_Time   : Timespec;
      Birth_Time    : Timespec;
      Size          : C_S64 := 0;
      Blocks        : C_S64 := 0;
      Block_Size    : C_S32 := 0;
      Flags         : C_U32 := 0;
      Generation    : C_U32 := 0;
      Long_Spare    : C_S32 := 0;
      Quad_Spare    : Spare_Array := [others => 0];
   end record with Convention => C;

   function C_Open (Path : Interfaces.C.Strings.chars_ptr; Flags : C_Int) return C_Int
     with Import, Convention => C, External_Name => "open";
   function C_Fstat (Descriptor : C_Int; Info : access Stat_Record) return C_Int
     with Import, Convention => C, External_Name => "fstat$INODE64";
   function C_Lseek (Descriptor : C_Int; Offset : File_Offset; Origin : C_Int) return File_Offset
     with Import, Convention => C, External_Name => "lseek";
   function C_Truncate (Descriptor : C_Int; Length : File_Offset) return C_Int
     with Import, Convention => C, External_Name => "ftruncate";

   function Open_Read
     (Path         : String;
      Follow_Links : Boolean;
      Supported    : out Boolean) return GNAT.OS_Lib.File_Descriptor
   is
      Name   : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Flags  : C_Int := O_Nonblock + O_Cloexec;
      Result : C_Int := -1;
      Info   : aliased Stat_Record;
   begin
      Supported := True;
      Name := Interfaces.C.Strings.New_String (Path);
      if not Follow_Links then
         Flags := Flags + O_Nofollow;
      end if;
      Result := C_Open (Name, Flags);
      Interfaces.C.Strings.Free (Name);
      if Result < 0
        or else C_Fstat (Result, Info'Access) /= 0
        or else (Info.Mode and File_Type_Mask) /= Regular_File
      then
         if Result >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Result));
         end if;
         return GNAT.OS_Lib.Invalid_FD;
      end if;
      return GNAT.OS_Lib.File_Descriptor (Result);
   exception
      when others =>
         if Result >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Result));
         end if;
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         return GNAT.OS_Lib.Invalid_FD;
   end Open_Read;

   function Skip_Zeros
     (Descriptor : GNAT.OS_Lib.File_Descriptor;
      Count      : Integer) return Boolean is
     (C_Lseek (C_Int (Descriptor), File_Offset (Count), 1) >= 0);

   function Finish_Sparse (Descriptor : GNAT.OS_Lib.File_Descriptor) return Boolean is
      Position : constant File_Offset := C_Lseek (C_Int (Descriptor), 0, 1);
   begin
      return Position >= 0 and then C_Truncate (C_Int (Descriptor), Position) = 0;
   end Finish_Sparse;
end Files.Platform_Regular_Files;
