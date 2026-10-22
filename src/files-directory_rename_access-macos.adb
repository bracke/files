with Hostkit.Darwin_Symbols;
with Ada.Directories;
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
   subtype C_S32 is Interfaces.C.int;
   subtype C_S64 is Interfaces.C.long;

   O_Evtonly   : constant C_Int := 16#8000#;
   O_Nofollow  : constant C_Int := 16#100#;
   O_Directory : constant C_Int := 16#10_0000#;
   O_Cloexec   : constant C_Int := 16#100_0000#;
   Owner_Write : constant C_U16 := 8#200#;
   Mode_Mask   : constant C_U16 := 8#7777#;

   type Timespec is record
      Seconds, Nanoseconds : C_S64 := 0;
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
      Access_Time, Modified_Time, Change_Time, Birth_Time : Timespec;
      Size, Blocks  : C_S64 := 0;
      Block_Size    : C_S32 := 0;
      Flags         : C_U32 := 0;
      Generation    : C_U32 := 0;
      Long_Spare    : C_S32 := 0;
      Quad_Spare    : Spare_Array := [others => 0];
   end record with Convention => C;

   function C_Open (Path : Interfaces.C.Strings.chars_ptr; Flags : C_Int) return C_Int
     with Import, Convention => C, External_Name => "open";
   function C_Fstat (Descriptor : C_Int; Info : access Stat_Record) return C_Int
     with Import, Convention => C, External_Name => Hostkit.Darwin_Symbols.Fstat;
   function C_Geteuid return C_U32
     with Import, Convention => C, External_Name => "geteuid";
   function C_Fchmod (Descriptor : C_Int; Mode : C_U16) return C_Int
     with Import, Convention => C, External_Name => "fchmod";

   function Prepare (Path : String; State : in out Context) return Boolean is
      Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Info : aliased Stat_Record;
      Fd   : C_Int := -1;
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
      Fd := C_Open (Name, O_Evtonly + O_Directory + O_Nofollow + O_Cloexec);
      Interfaces.C.Strings.Free (Name);
      if Fd < 0 or else C_Fstat (Fd, Info'Access) /= 0 then
         if Fd >= 0 then
            GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Fd));
            Fd := -1;
         end if;
         return False;
      end if;
      if Info.User_Id /= C_Geteuid or else (Info.Mode and Owner_Write) /= 0 then
         GNAT.OS_Lib.Close (GNAT.OS_Lib.File_Descriptor (Fd));
         Fd := -1;
         return True;
      end if;
      State.Descriptor := GNAT.OS_Lib.File_Descriptor (Fd);
      Fd := -1;
      State.Mode := C_U32 (Info.Mode and Mode_Mask);
      if C_Fchmod
        (C_Int (State.Descriptor), C_U16 (State.Mode) or Owner_Write) /= 0
      then
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
         Release (State);
         return False;
   end Prepare;

   function Finish (State : in out Context) return Boolean is
   begin
      if not State.Restore then
         return True;
      end if;
      if C_Fchmod (C_Int (State.Descriptor), C_U16 (State.Mode)) /= 0 then
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
