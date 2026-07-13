with Ada.Directories;

with Interfaces.C.Strings;

package body Files.Platform.Symlinks is

   use type Ada.Directories.File_Kind;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;

   --  CreateSymbolicLink needs a flag saying whether the target is a directory,
   --  and -- unlike POSIX -- it needs a privilege the caller may not hold. Since
   --  Windows 10 the unprivileged flag lets it work under Developer Mode; without
   --  either, it simply fails, and a caller that cannot make a link is expected
   --  to carry on without one.
   Flag_Directory   : constant Interfaces.C.unsigned_long := 16#1#;
   Flag_Unprivileged : constant Interfaces.C.unsigned_long := 16#2#;

   function Create_Symbolic_Link
     (Link_Path   : Interfaces.C.Strings.chars_ptr;
      Target      : Interfaces.C.Strings.chars_ptr;
      Flags       : Interfaces.C.unsigned_long) return Interfaces.C.char
     with Import, Convention => Stdcall,
          External_Name => "CreateSymbolicLinkA";

   function Create (Target : String; Link_Path : String) return Boolean is
      C_Target : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Target);
      C_Link   : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Link_Path);
      Flags    : Interfaces.C.unsigned_long := Flag_Unprivileged;
      Result   : Interfaces.C.char;
   begin
      --  The argument order is the reverse of POSIX: link first, then target.
      if Ada.Directories.Exists (Target)
        and then Ada.Directories.Kind (Target) = Ada.Directories.Directory
      then
         Flags := Flags or Flag_Directory;
      end if;

      Result := Create_Symbolic_Link (C_Link, C_Target, Flags);
      Interfaces.C.Strings.Free (C_Target);
      Interfaces.C.Strings.Free (C_Link);

      return Interfaces.C.char'Pos (Result) /= 0;

   exception
      when others =>
         if C_Target /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Target);
         end if;
         if C_Link /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (C_Link);
         end if;
         return False;
   end Create;

end Files.Platform.Symlinks;
