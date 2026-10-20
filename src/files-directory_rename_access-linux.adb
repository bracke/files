with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces.C.Strings;

with Hostkit.Fs;

package body Files.Directory_Rename_Access is
   use type Ada.Directories.File_Kind;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Interfaces.C.int;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_short;
   use type Interfaces.C.Strings.chars_ptr;

   subtype C_Int is Interfaces.C.int;
   subtype C_U16 is Interfaces.C.unsigned_short;
   subtype C_U32 is Interfaces.C.unsigned;
   subtype C_U64 is Interfaces.C.unsigned_long;
   subtype C_S64 is Interfaces.C.long;

   --  asm-generic/fcntl.h is right for x86, riscv and most targets, but arm,
   --  arm64, powerpc and m68k define their own O_DIRECTORY and O_NOFOLLOW (and
   --  give the generic O_NOFOLLOW bit to O_LARGEFILE), so a hard-coded x86
   --  value silently follows a final symlink there. Pick by the machine.
   function Uses_Alternate_Open_Flags return Boolean is
      use type Interfaces.C.char;
      type Uts_Field is array (1 .. 65) of Interfaces.C.char with Convention => C;
      type Uts_Name is record
         Sysname, Nodename, Release, Version, Machine, Domainname : Uts_Field;
      end record with Convention => C;
      function uname (Buffer : access Uts_Name) return C_Int
        with Import, Convention => C, External_Name => "uname";
      Info    : aliased Uts_Name;
      Machine : String (1 .. Uts_Field'Length);
      Last    : Natural := 0;

      function Starts (Prefix : String) return Boolean is
        (Last >= Prefix'Length and then Machine (1 .. Prefix'Length) = Prefix);
   begin
      if uname (Info'Access) /= 0 then
         return False;
      end if;
      for Char of Info.Machine loop
         exit when Char = Interfaces.C.nul;
         Last := Last + 1;
         Machine (Last) := Interfaces.C.To_Ada (Char);
      end loop;
      return Starts ("arm") or else Starts ("aarch64") or else Starts ("ppc")
        or else Starts ("powerpc") or else Starts ("m68k");
   end Uses_Alternate_Open_Flags;

   Alternate_Open_Flags : constant Boolean := Uses_Alternate_Open_Flags;

   O_Path      : constant C_Int := 16#20_0000#;
   O_Directory : constant C_Int := (if Alternate_Open_Flags then 16#4000# else 16#1_0000#);
   O_Nofollow  : constant C_Int := (if Alternate_Open_Flags then 16#8000# else 16#2_0000#);
   O_Cloexec   : constant C_Int := 16#8_0000#;
   At_Empty_Path : constant C_Int := 16#1000#;
   Statx_Mode_User : constant C_U32 := 16#00A#;
   Owner_Write : constant C_U16 := 8#200#;
   Mode_Mask   : constant C_U16 := 8#7777#;

   type U16_Array is array (Positive range <>) of C_U16 with Convention => C;
   type U64_Array is array (Positive range <>) of C_U64 with Convention => C;
   type Statx_Timestamp is record
      Seconds : C_S64;
      Nanoseconds, Reserved : C_U32;
   end record with Convention => C;
   type Statx_Record is record
      Mask, Block_Size       : C_U32;
      Attributes             : C_U64;
      Link_Count, User_Id, Group_Id : C_U32;
      Mode                   : C_U16;
      Spare_0                : U16_Array (1 .. 1);
      Inode, Size, Blocks, Attributes_Mask : C_U64;
      Access_Time, Birth_Time, Change_Time, Modified_Time : Statx_Timestamp;
      Special_Device_Major, Special_Device_Minor, Device_Major, Device_Minor : C_U32;
      Mount_Id               : C_U64;
      Direct_Io_Memory_Align, Direct_Io_Offset_Align : C_U32;
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
   function C_Geteuid return C_U32
     with Import, Convention => C, External_Name => "geteuid";
   function C_Chmod (Path : Interfaces.C.Strings.chars_ptr; Mode : C_U32) return C_Int
     with Import, Convention => C, External_Name => "chmod";

   function Held_Path (Descriptor : GNAT.OS_Lib.File_Descriptor) return String is
     ("/proc/self/fd/" & Ada.Strings.Fixed.Trim
        (GNAT.OS_Lib.File_Descriptor'Image (Descriptor), Ada.Strings.Both));

   function Set_Mode (Descriptor : GNAT.OS_Lib.File_Descriptor; Mode : C_U32) return Boolean is
      Name   : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Held_Path (Descriptor));
      Status : C_Int;
   begin
      Status := C_Chmod (Name, Mode);
      Interfaces.C.Strings.Free (Name);
      return Status = 0;
   exception
      when others =>
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         return False;
   end Set_Mode;

   function Prepare (Path : String; State : in out Context) return Boolean is
      Name  : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Empty : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Info  : aliased Statx_Record;
      Fd    : C_Int := -1;
   begin
      Release (State);
      if Hostkit.Fs.Is_Link (Path) then
         return True;
      end if;
      if not Ada.Directories.Exists (Path) then
         return False;
      end if;
      if Ada.Directories.Kind (Path) /= Ada.Directories.Directory then
         return True;
      end if;
      Name := Interfaces.C.Strings.New_String (Path);
      Empty := Interfaces.C.Strings.New_String ("");
      Fd := C_Open (Name, O_Path + O_Directory + O_Nofollow + O_Cloexec);
      Interfaces.C.Strings.Free (Name);
      if Fd < 0
        or else C_Statx (Fd, Empty, At_Empty_Path, Statx_Mode_User, Info'Access) /= 0
        or else (Info.Mask and Statx_Mode_User) /= Statx_Mode_User
      then
         if Fd >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Fd));
            Fd := -1;
         end if;
         Interfaces.C.Strings.Free (Empty);
         return False;
      end if;
      Interfaces.C.Strings.Free (Empty);
      if Info.User_Id /= C_Geteuid or else (Info.Mode and Owner_Write) /= 0 then
         GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Fd));
         Fd := -1;
         return True;
      end if;
      State.Descriptor := GNAT.OS_Lib.File_Descriptor (Fd);
      Fd := -1;
      State.Mode := C_U32 (Info.Mode and Mode_Mask);
      if not Set_Mode (State.Descriptor, State.Mode + C_U32 (Owner_Write)) then
         Release (State);
         return False;
      end if;
      State.Restore := True;
      return True;
   exception
      when others =>
         if Fd >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Fd));
         end if;
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         if Empty /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Empty);
         end if;
         Release (State);
         return False;
   end Prepare;

   function Finish (State : in out Context) return Boolean is
   begin
      if not State.Restore then
         return True;
      end if;
      if not Set_Mode (State.Descriptor, State.Mode) then
         return False;
      end if;
      Release (State);
      return True;
   end Finish;

   procedure Release (State : in out Context) is
   begin
      if State.Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (State.Descriptor);
      end if;
      State.Descriptor := GNAT.OS_Lib.Invalid_FD;
      State.Mode := 0;
      State.Restore := False;
   end Release;
end Files.Directory_Rename_Access;
