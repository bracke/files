with GNAT.OS_Lib;

with Interfaces.C.Strings;

package body Files.Platform.Symlinks is

   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;

   function C_Symlink
     (Target   : Interfaces.C.Strings.chars_ptr;
      Link_Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "symlink";

   function Is_Link (Path : String) return Boolean is
   begin
      return GNAT.OS_Lib.Is_Symbolic_Link (Path);
   exception
      when others =>
         return False;
   end Is_Link;

   function Create (Target : String; Link_Path : String) return Boolean is
      C_Target : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Target);
      C_Link   : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Link_Path);
      Result   : Interfaces.C.int;
   begin
      Result := C_Symlink (C_Target, C_Link);
      Interfaces.C.Strings.Free (C_Target);
      Interfaces.C.Strings.Free (C_Link);
      return Result = 0;

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
