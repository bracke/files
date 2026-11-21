with Files.Diagnostics;
with Ada.IO_Exceptions;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Hostkit.Fs;
with Files.File_System;
with Files.IO.Fs_Primitives;
with Files.Types;
with Files.Text_Case;

package body Files.Archive_Writing is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_64;
   use type Zlib.Status_Code;

   package Archive_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");
   type Text_Array_Access is access Zlib.Text_Array;
   procedure Free_Text_Array is new Ada.Unchecked_Deallocation
     (Zlib.Text_Array, Text_Array_Access);

   Max_Extraction_Entries   : constant := 100_000;
   Max_Extraction_Path_Bytes : constant Interfaces.Unsigned_64 :=
     64 * 1024 * 1024;
   Max_Unknown_Extraction_Bytes : constant Interfaces.Unsigned_64 :=
     256 * 1024 * 1024 * 1024;
   Expansion_Floor : constant Interfaces.Unsigned_64 :=
     4 * 1024 * 1024 * 1024;
   Max_Expansion_Ratio : constant Interfaces.Unsigned_64 := 10_000;
   Max_Free_Byte_Reserve : constant Interfaces.Unsigned_64 :=
     1024 * 1024 * 1024;
   Max_Free_Inode_Reserve : constant Interfaces.Unsigned_64 := 1_024;

   --  A relative, '/'-separated name with no empty, "." or ".." component
   --  that Portable_Entry_Name accepts.
   function Safe_Archive_Name (Name : String) return Boolean is
      First : Positive := Name'First;
   begin
      if Name = "" or else not Portable_Entry_Name (Name) then
         return False;
      end if;
      for I in Name'Range loop
         if Name (I) = '/' then
            if I = First or else I = Name'Last or else Name (First .. I - 1) in "." | ".." then
               return False;
            end if;
            First := I + 1;
         end if;
      end loop;
      return Name (First .. Name'Last) not in "." | "..";
   end Safe_Archive_Name;

   function First_Unextractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return String
   is
      Names_Seen : Archive_Name_Sets.Set;

      --  Whether every '/'-separated segment of Path is one the destination
      --  can store.
      function Storable (Path : String) return Boolean is
         First : Positive := Path'First;
      begin
         if not Dos_Rules then
            return True;
         end if;
         for I in Path'First .. Path'Last + 1 loop
            if I > Path'Last or else Path (I) = '/' then
               if I > First
                 and then not Files.File_System.Valid_Leaf_Name (Path (First .. I - 1), Files.File_System.Windows_Rules)
               then
                  return False;
               end if;
               First := I + 1;
            end if;
         end loop;
         return True;
      end Storable;

      --  The name two entries collide under on the destination.
      function Key (Path : String) return String is
        (if Case_Insensitive then Files.Text_Case.Fold_Case (Path) else Path);
   begin
      for Member of Entries loop
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Member.Name);
            Path : constant String := Zlib.Entry_Path_Name (Name);
            Is_Directory_Entry : constant Boolean := Path /= "" and then Path (Path'Last) = '/';
            Relative : constant String :=
              (if Is_Directory_Entry then Path (Path'First .. Path'Last - 1) else Path);
         begin
            --  A repeated directory entry is harmless (some writers emit one
            --  per member); only a repeated file would silently overwrite.
            if Relative = ""
              or else not Zlib.Safe_Entry_Path (Relative)
              or else not Storable (Relative)
              or else (not Is_Directory_Entry and then Names_Seen.Contains (Key (Relative)))
            then
               --  A nameless entry would write the destination itself: it
               --  is named by the "/" it stands for, never "" (all clear).
               return (if Name = "" then "/" else Name);
            end if;
            Names_Seen.Include (Key (Relative));
         end;
      end loop;
      return "";
   end First_Unextractable;

   function Names_Are_Extractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return Boolean is
     (First_Unextractable (Entries, Dos_Rules, Case_Insensitive) = "");

   function First_Unextractable_At
     (Entries     : Zlib.Archive_Entry_Array;
      Destination : String) return String is
     (First_Unextractable
        (Entries,
         Dos_Rules        => Destination /= "" and then Hostkit.Fs.Uses_Dos_Filename_Rules (Destination),
         Case_Insensitive => Destination /= "" and then Hostkit.Fs.Folds_Name_Case (Destination)));

   function Extraction_Is_Within_Limits
     (Entries            : Zlib.Archive_Entry_Array;
      Free_Bytes         : Long_Long_Integer;
      Free_Bytes_Known   : Boolean;
      Free_Inodes        : Long_Long_Integer;
      Free_Inodes_Known  : Boolean;
      Destination        : String := "") return Boolean
   is
      subtype U64 is Interfaces.Unsigned_64;
      Dos_Rules          : constant Boolean :=
        Destination /= "" and then Hostkit.Fs.Uses_Dos_Filename_Rules (Destination);
      Total_Uncompressed : U64 := 0;
      Total_Compressed   : U64 := 0;
      Total_Path_Bytes   : U64 := 0;

      function Add_Would_Overflow (Left, Right : U64) return Boolean is
        (Left > U64'Last - Right);

      function Saturating_Multiply (Left, Right : U64) return U64 is
        (if Left = 0 or else Right = 0 then 0
         elsif Left > U64'Last / Right then U64'Last
         else Left * Right);

      function Saturating_Add (Left, Right : U64) return U64 is
        (if Add_Would_Overflow (Left, Right) then U64'Last
         else Left + Right);
   begin
      if Entries'Length > Max_Extraction_Entries
        or else not Names_Are_Extractable
          (Entries,
           Dos_Rules        => Dos_Rules,
           Case_Insensitive => Destination /= "" and then Hostkit.Fs.Folds_Name_Case (Destination))
      then
         return False;
      end if;

      for Member of Entries loop
         declare
            Path_Bytes : constant U64 :=
              U64 (Ada.Strings.Unbounded.Length (Member.Name));
         begin
            --  A repeated directory entry is harmless (some writers emit one
            --  per member); only a repeated file would silently overwrite.
            if Add_Would_Overflow (Total_Uncompressed, Member.Uncompressed_Size)
              or else Add_Would_Overflow (Total_Compressed, Member.Compressed_Size)
              or else Add_Would_Overflow (Total_Path_Bytes, Path_Bytes)
            then
               return False;
            end if;
            Total_Uncompressed := Total_Uncompressed + Member.Uncompressed_Size;
            Total_Compressed := Total_Compressed + Member.Compressed_Size;
            Total_Path_Bytes := Total_Path_Bytes + Path_Bytes;
         end;
      end loop;

      if Total_Path_Bytes > Max_Extraction_Path_Bytes
        or else Total_Uncompressed >
          Saturating_Add
            (Expansion_Floor,
             Saturating_Multiply (Total_Compressed, Max_Expansion_Ratio))
      then
         return False;
      end if;

      if Free_Bytes_Known then
         if Free_Bytes < 0 then
            return False;
         end if;
         declare
            Available : constant U64 := U64 (Free_Bytes);
            Reserve   : constant U64 :=
              U64'Min (Max_Free_Byte_Reserve, Available / 20);
         begin
            if Total_Uncompressed > Available - Reserve then
               return False;
            end if;
         end;
      elsif Total_Uncompressed > Max_Unknown_Extraction_Bytes then
         return False;
      end if;

      if Free_Inodes_Known then
         if Free_Inodes < 0 then
            return False;
         end if;
         declare
            Available : constant U64 := U64 (Free_Inodes);
            Reserve   : constant U64 :=
              U64'Min (Max_Free_Inode_Reserve, Available / 20);
         begin
            if U64 (Entries'Length) > Available - Reserve then
               return False;
            end if;
         end;
      end if;

      return True;
   end Extraction_Is_Within_Limits;

   procedure ZIP_Files
     (Input_Paths : Zlib.Text_Array;
      Output_Path : String;
      Entry_Names : Zlib.Text_Array;
      Status : out Zlib.Status_Code)
   is
      File_Paths, File_Names, Directory_Names : Files.Types.String_Vectors.Vector;
      Names_Seen : Archive_Name_Sets.Set;
      Paths, Names, Directories : Text_Array_Access := null;

      procedure Free is
      begin
         Free_Text_Array (Paths);
         Free_Text_Array (Names);
         Free_Text_Array (Directories);
      end Free;

      --  A failed write leaves nothing behind for the caller to publish.
      procedure Remove_Partial_Output is
      begin
         --  Only an output that is gone for sure is skipped: one a refused
         --  lookup cannot see is still tried, and a failed delete is noted.
         if not Files.IO.Fs_Primitives.Entry_Is_Absent (Output_Path) then
            Files.IO.Fs_Primitives.Delete_File (Output_Path);
         end if;
      exception
         when Failed : Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
            Files.Diagnostics.Note (Failed, "Files.Archive_Writing");
      end Remove_Partial_Output;
   begin
      Status := Zlib.Unsupported_Method;
      if Input_Paths'Length = 0 or else Input_Paths'Length /= Entry_Names'Length
        or else Input_Paths'Length > 65_535
      then
         return;
      end if;
      for I in 0 .. Input_Paths'Length - 1 loop
         declare
            Path : constant String := To_String (Input_Paths (Input_Paths'First + I));
            Name : constant String := To_String (Entry_Names (Entry_Names'First + I));
         begin
            if not Safe_Archive_Name (Name) or else Name'Length >= 65_535 then
               return;
            end if;
            if Names_Seen.Contains (Name) then
               return;
            end if;
            Names_Seen.Insert (Name);
            Status := Zlib.Input_File_Error;
            if Files.IO.Fs_Primitives.Kind (Path) = Ada.Directories.Directory then
               Directory_Names.Append (To_Unbounded_String (Name));
            else
               File_Paths.Append (To_Unbounded_String (Path));
               File_Names.Append (To_Unbounded_String (Name));
            end if;
         end;
      end loop;

      --  Zlib writes the files' members, then each directory as a
      --  zero-length member named with a trailing "/".
      Paths := new Zlib.Text_Array (1 .. Natural (File_Paths.Length));
      Names := new Zlib.Text_Array (1 .. Natural (File_Paths.Length));
      Directories := new Zlib.Text_Array (1 .. Natural (Directory_Names.Length));
      for I in Paths.all'Range loop
         Paths.all (I) := File_Paths (I);
         Names.all (I) := File_Names (I);
      end loop;
      for I in Directories.all'Range loop
         Directories.all (I) := Directory_Names (I);
      end loop;
      Zlib.ZIP_Files (Paths.all, Output_Path, Names.all, Directories.all, Status => Status);
      Free;
      if Status /= Zlib.Ok then
         Remove_Partial_Output;
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Archive_Writing");
         Free;
         Remove_Partial_Output;
   end ZIP_Files;
end Files.Archive_Writing;
