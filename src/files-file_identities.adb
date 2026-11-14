with Files.Diagnostics;
with Ada.Strings.Unbounded;

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
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_Identities");
         return "";
   end Revision;

   function Image (Item : Hostkit.Metadata.Entry_Identity) return String is
     (if not Item.Available then ""
      else U64'Image (Item.Volume) & U64'Image (Item.File_Number)
        & U64'Image (Item.Generation_High) & U64'Image (Item.Generation_Low));

   function Parse (Text : String; Item : out Hostkit.Metadata.Entry_Identity) return Boolean is
      Position : Natural := Text'First;
      Values   : array (1 .. 4) of U64 := [others => 0];

      procedure Skip_Spaces is
      begin
         while Position <= Text'Last and then Text (Position) = ' ' loop
            Position := Position + 1;
         end loop;
      end Skip_Spaces;
   begin
      Item := (others => <>);
      for Index in Values'Range loop
         Skip_Spaces;
         if Position > Text'Last or else Text (Position) not in '0' .. '9' then
            return False;
         end if;
         declare
            First : constant Natural := Position;
         begin
            while Position <= Text'Last and then Text (Position) in '0' .. '9' loop
               Position := Position + 1;
            end loop;
            Values (Index) := U64'Value (Text (First .. Position - 1));
         end;
      end loop;
      Skip_Spaces;
      if Position <= Text'Last then
         return False;
      end if;
      Item :=
        (Available       => True,
         Volume          => Values (1),
         File_Number     => Values (2),
         Generation_High => Values (3),
         Generation_Low  => Values (4));
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_Identities");
         Item := (others => <>);
         return False;
   end Parse;

   function Token (Path : String) return String is
      Value : Hostkit.Metadata.Entry_Identity;
   begin
      if Test_Identity_Unavailable then
         return "";
      end if;
      Value := Hostkit.Metadata.Entry_Identity_Of (Path);
      return Image (Value);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_Identities");
         return "";
   end Token;
end Files.File_Identities;
