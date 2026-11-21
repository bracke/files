with Ada.Strings.Unbounded;

package body Files.IO.Fs_Primitives.Testing is
   use Ada.Strings.Unbounded;

   --  What Refuse_Lookups armed.
   Refused_Path : Unbounded_String;

   --  Path with every '\' read as '/'.
   function Slashed (Path : String) return String is
      Result : String := Path;
   begin
      for Item of Result loop
         if Item = '\' then
            Item := '/';
         end if;
      end loop;
      return Result;
   end Slashed;

   --  The Refuse_Lookup hook Refuse_Lookups installs.
   function Refuse (Path : String) return Boolean is
     (Slashed (Path) = Slashed (To_String (Refused_Path)));

   procedure Refuse_Lookups (Path : String) is
   begin
      Refused_Path := To_Unbounded_String (Path);
      Refuse_Lookup := Refuse'Access;
   end Refuse_Lookups;

   procedure Stop_Refusing_Lookups is
   begin
      Refuse_Lookup := null;
      Refused_Path := Null_Unbounded_String;
   end Stop_Refusing_Lookups;

end Files.IO.Fs_Primitives.Testing;
