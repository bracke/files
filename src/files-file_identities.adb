with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Strings.Unbounded;

package body Files.File_Identities is
   use type Interfaces.C.int;
   use type Interfaces.C.Strings.chars_ptr;
   subtype U64 is Interfaces.C.unsigned_long_long;
   type Entry_Identity is record
      Volume, Number, Birth_Seconds, Birth_Nanoseconds : U64;
   end record with Convention => C;
   function Read_Identity
     (Path : Interfaces.C.Strings.chars_ptr;
      Value : access Entry_Identity) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_entry_identity";

   type Entry_Revision is array (1 .. 8) of U64 with Convention => C;
   function Read_Revision
     (Path : Interfaces.C.Strings.chars_ptr; Value : access Entry_Revision) return Interfaces.C.int
     with Import, Convention => C, External_Name => "files_entry_revision";

   function Revision (Path : String; Include_Change_Time : Boolean := True) return String is
      Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Value : aliased Entry_Revision;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Status : Interfaces.C.int;
   begin
      Status := Read_Revision (Name, Value'Access);
      Interfaces.C.Strings.Free (Name);
      if Status /= 1 then
         return "";
      end if;
      if not Include_Change_Time then
         Value (3 .. 4) := [others => 0];
      end if;
      for Field of Value loop
         Ada.Strings.Unbounded.Append (Result, U64'Image (Field));
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         return "";
   end Revision;

   function Token (Path : String) return String is
      Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Value : aliased Entry_Identity;
      Status : Interfaces.C.int;
   begin
      if Test_Identity_Unavailable then
         return "";
      end if;
      Name := Interfaces.C.Strings.New_String (Path);
      Status := Read_Identity (Name, Value'Access);
      Interfaces.C.Strings.Free (Name);
      if Status /= 1 then
         return "";
      end if;
      return U64'Image (Value.Volume) & U64'Image (Value.Number)
        & U64'Image (Value.Birth_Seconds) & U64'Image (Value.Birth_Nanoseconds);
   exception
      when others =>
         if Name /= Interfaces.C.Strings.Null_Ptr then
            Interfaces.C.Strings.Free (Name);
         end if;
         return "";
   end Token;
end Files.File_Identities;
