with Hostkit.Metadata;
with Interfaces;

separate (Files.File_System)
procedure Add_To_Signature
  (Result : in out Directory_Signature;
   Name   : String)
is
   function Entry_Checksum
     (Name : String;
      Kind : Ada.Directories.File_Kind;
      Size : Long_Long_Integer)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Value   : Long_Long_Integer := Long_Long_Integer (Ada.Directories.File_Kind'Pos (Kind) + 1);
   begin
      for Character_Value of Name loop
         Value :=
           (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
      end loop;

      Value := (Value * 131 + Long_Long_Integer'Max (0, Size)) mod Modulus;
      return Natural (Value);
   end Entry_Checksum;

   --  One no-follow stat answers everything a listing shows: both times
   --  (a chmod or chown moves only the change time; cp -p keeps an old
   --  modification time), the size, the mode with the entry's type, and the
   --  owner. Ada.Directories took about three stats per question asked.
   function Revision_Checksum
     (Name     : String;
      Revision : Hostkit.Metadata.Entry_Revision)
      return Natural
   is
      Modulus : constant Interfaces.Unsigned_64 := 1_000_000_007;
      Value   : Interfaces.Unsigned_64 := 7;

      procedure Mix (Field : Interfaces.Unsigned_64) is
         use type Interfaces.Unsigned_64;
      begin
         Value := (Value * 131 + Field mod Modulus) mod Modulus;
      end Mix;
   begin
      for Character_Value of Name loop
         Mix (Interfaces.Unsigned_64 (Character'Pos (Character_Value)));
      end loop;
      Mix (Revision.Modified_Seconds);
      Mix (Revision.Modified_Nanoseconds);
      Mix (Revision.Changed_Seconds);
      Mix (Revision.Changed_Nanoseconds);
      Mix (Revision.Size);
      Mix (Revision.Mode);
      Mix (Revision.User_Id);
      Mix (Revision.Group_Id);
      return Natural (Value);
   end Revision_Checksum;

   Revision : constant Hostkit.Metadata.Entry_Revision :=
     Hostkit.Metadata.Entry_Revision_Of (Hostkit.Fs.Join (To_String (Result.Path), Name));
begin
   Result.Entry_Count := Result.Entry_Count + 1;
   if Revision.Available then
      Result.Entry_State_Checksum :=
        (Result.Entry_State_Checksum + Revision_Checksum (Name, Revision)) mod 1_000_000_007;
      return;
   end if;
   declare
      Full     : constant String := Hostkit.Fs.Join (To_String (Result.Path), Name);
      Kind     : Ada.Directories.File_Kind := Ada.Directories.Special_File;
      Size     : Long_Long_Integer := 0;
      Modified : Ada.Calendar.Time := Files.Types.Unknown_Time;
   begin
      begin
         Kind := Files.Fs_Primitives.Kind (Full);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end;

      if Kind = Ada.Directories.Ordinary_File then
         begin
            Size := Long_Long_Integer (Files.Fs_Primitives.Size (Full));
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System");
               Size := 0;
         end;
      end if;

      Result.Entry_State_Checksum :=
        (Result.Entry_State_Checksum + Entry_Checksum (Name, Kind, Size)) mod 1_000_000_007;

      begin
         Modified := Files.Fs_Primitives.Modification_Time (Full);
         if not Result.Latest_Modified_Known
           or else Modified > Result.Latest_Modified
         then
            Result.Latest_Modified := Modified;
            Result.Latest_Modified_Known := True;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
      end;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         Result.Entry_State_Checksum :=
           (Result.Entry_State_Checksum
            + Entry_Checksum (Name, Ada.Directories.Special_File, 0)) mod 1_000_000_007;
   end;
end Add_To_Signature;
