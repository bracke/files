with Ada.Strings.Unbounded;
with Hostkit.Metadata;

package body Files.File_Identities is
   subtype U64 is Hostkit.Metadata.Identity_Field;

   function Revision (Path : String; Include_Change_Time : Boolean := True) return String is
      Value  : Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Path);
      Result : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Value.Available then
         return "";
      end if;
      if not Include_Change_Time then
         Value.Changed_Seconds := 0;
         Value.Changed_Nanoseconds := 0;
      end if;
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Modified_Seconds));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Modified_Nanoseconds));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Changed_Seconds));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Changed_Nanoseconds));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Size));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Mode));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.User_Id));
      Ada.Strings.Unbounded.Append (Result, U64'Image (Value.Group_Id));
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         return "";
   end Revision;

   function Token (Path : String) return String is
      Value : Hostkit.Metadata.Entry_Identity;
   begin
      if Test_Identity_Unavailable then
         return "";
      end if;
      Value := Hostkit.Metadata.Entry_Identity_Of (Path);
      if not Value.Available then
         return "";
      end if;
      return U64'Image (Value.Volume) & U64'Image (Value.File_Number)
        & U64'Image (Value.Generation_High) & U64'Image (Value.Generation_Low);
   exception
      when others =>
         return "";
   end Token;
end Files.File_Identities;
