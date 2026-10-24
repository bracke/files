with Ada.IO_Exceptions;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Hostkit.Fs;
with Hostkit.Host;
with Files.File_System;
with Files.Job_Context;
with Files.Types;

package body Files.Archive_Writing is
   use Ada.Strings.Unbounded;
   use Ada.Streams;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_IO.Count;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Zlib.Status_Code;

   subtype U32 is Interfaces.Unsigned_32;
   package Archive_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");
   type Text_Array_Access is access Zlib.Text_Array;
   procedure Free_Text_Array is new Ada.Unchecked_Deallocation
     (Zlib.Text_Array, Text_Array_Access);
   type U32_Array is array (Positive range <>) of U32;
   type U32_Array_Access is access U32_Array;
   procedure Free_U32_Array is new Ada.Unchecked_Deallocation
     (U32_Array, U32_Array_Access);

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

   function Safe_Archive_Name
     (Name                     : String;
      Allow_Trailing_Separator : Boolean := False) return Boolean
   is
      First : Positive := Name'First;
   begin
      if Name = "" then
         return False;
      end if;
      for I in Name'Range loop
         if Name (I) = ASCII.NUL or else Name (I) = '\' or else Name (I) = ':' then
            return False;
         elsif Name (I) = '/' then
            if I = First
              or else Name (First .. I - 1) in "." | ".."
              or else (I = Name'Last and then not Allow_Trailing_Separator)
            then
               return False;
            end if;
            First := I + 1;
         end if;
      end loop;
      return
        (Allow_Trailing_Separator and then First = Name'Last + 1)
        or else
          (First <= Name'Last and then Name (First .. Name'Last) not in "." | "..");
   end Safe_Archive_Name;

   function Names_Are_Extractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return Boolean
   is
      Names_Seen : Archive_Name_Sets.Set;

      --  Whether every '/'-separated segment of Name is one the destination
      --  can store.
      function Storable (Name : String) return Boolean is
         First : Positive := Name'First;
      begin
         if not Dos_Rules then
            return True;
         end if;
         for I in Name'First .. Name'Last + 1 loop
            if I > Name'Last or else Name (I) = '/' then
               if I > First
                 and then not Files.File_System.Valid_Leaf_Name (Name (First .. I - 1), Files.File_System.Windows_Rules)
               then
                  return False;
               end if;
               First := I + 1;
            end if;
         end loop;
         return True;
      end Storable;

      --  The name two entries collide under on the destination.
      function Key (Name : String) return String is
        (if Case_Insensitive then Files.Types.To_Lower (Name) else Name);
   begin
      for Member of Entries loop
         declare
            Name : constant String := Ada.Strings.Unbounded.To_String (Member.Name);
            Is_Directory_Entry : constant Boolean :=
              Name /= "" and then Name (Name'Last) = '/';
         begin
            --  A repeated directory entry is harmless (some writers emit one
            --  per member); only a repeated file would silently overwrite.
            if not Safe_Archive_Name (Name, Allow_Trailing_Separator => Is_Directory_Entry)
              or else not Storable (Name)
              or else (not Is_Directory_Entry and then Names_Seen.Contains (Key (Name)))
            then
               return False;
            end if;
            Names_Seen.Include (Key (Name));
         end;
      end loop;
      return True;
   end Names_Are_Extractable;

   function Extraction_Is_Within_Limits
     (Entries            : Zlib.Archive_Entry_Array;
      Free_Bytes         : Long_Long_Integer;
      Free_Bytes_Known   : Boolean;
      Free_Inodes        : Long_Long_Integer;
      Free_Inodes_Known  : Boolean;
      Destination        : String := "") return Boolean
   is
      use type Hostkit.Host.Kind;
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
           Case_Insensitive =>
             Dos_Rules or else (Destination /= "" and then Hostkit.Host.Current = Hostkit.Host.MacOS))
      then
         return False;
      end if;

      for Member of Entries loop
         declare
            Name : constant String := To_String (Member.Name);
            Is_Directory_Entry : constant Boolean :=
              Name /= "" and then Name (Name'Last) = '/';
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
      package IO renames Ada.Streams.Stream_IO;
      Source, Output : IO.File_Type;
      File_Paths, File_Names, Directory_Names : Files.Types.String_Vectors.Vector;
      Names_Seen : Archive_Name_Sets.Set;
      Source_Path : constant String := Output_Path & ".files";
      Central_Offset, Central_Size : U32 := 0;
      End_Record : Stream_Element_Array (1 .. 22);
      Last : Stream_Element_Offset;

      function Number (First : Stream_Element_Offset; Width : Positive) return U32 is
         Value : U32 := 0;
      begin
         for I in 0 .. Width - 1 loop
            Value := Value or Interfaces.Shift_Left (U32 (End_Record (First + Stream_Element_Offset (I))), 8 * I);
         end loop;
         return Value;
      end Number;

      function Offset return U32 is
         Position : constant IO.Count := IO.Count (IO.Index (Output)) - 1;
      begin
         if Position > IO.Count (U32'Last) then
            raise IO.Use_Error;
         end if;
         return U32 (Position);
      end Offset;

      procedure Put (Value : U32; Width : Positive) is
         Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Width));
      begin
         for I in 0 .. Width - 1 loop
            Bytes (Stream_Element_Offset (I + 1)) :=
              Stream_Element (Interfaces.Shift_Right (Value, 8 * I) and 16#FF#);
         end loop;
         IO.Write (Output, Bytes);
      end Put;

      procedure Put_Name (Name : String) is
         Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Name'Length));
      begin
         for I in Name'Range loop
            Bytes (Stream_Element_Offset (I - Name'First + 1)) := Stream_Element (Character'Pos (Name (I)));
         end loop;
         IO.Write (Output, Bytes);
      end Put_Name;

      procedure Copy (Count : U32) is
         Remaining : IO.Count := IO.Count (Count);
         Buffer : Stream_Element_Array (1 .. 65_536);
         Chunk : Stream_Element_Offset;
      begin
         while Remaining > 0 loop
            if Files.Job_Context.Cancelled then
               raise IO.Use_Error;
            end if;
            Chunk := Stream_Element_Offset (IO.Count'Min (Remaining, IO.Count (Buffer'Length)));
            IO.Read (Source, Buffer (1 .. Chunk), Last);
            if Last /= Chunk then
               raise IO.Data_Error;
            end if;
            IO.Write (Output, Buffer (1 .. Last));
            Remaining := Remaining - IO.Count (Last);
         end loop;
      end Copy;

      procedure Close (File : in out IO.File_Type) is
      begin
         if IO.Is_Open (File) then
            IO.Close (File);
         end if;
      end Close;
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
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Directory_Names.Append (To_Unbounded_String (Name & "/"));
            else
               File_Paths.Append (To_Unbounded_String (Path));
               File_Names.Append (To_Unbounded_String (Name));
            end if;
         end;
      end loop;

      --  Zlib writes file payloads and their central records. Directory-only
      --  archives start with no payload or central records. Rebuild the staged
      --  ZIP32 layout with zero-byte directory members and one final catalog.
      if not File_Paths.Is_Empty then
         declare
            Paths, Names : Text_Array_Access := null;
         begin
            Paths := new Zlib.Text_Array (1 .. Natural (File_Paths.Length));
            Names := new Zlib.Text_Array (1 .. Natural (File_Paths.Length));
            for I in Paths.all'Range loop
               Paths.all (I) := File_Paths (I);
               Names.all (I) := File_Names (I);
            end loop;
            Zlib.ZIP_Files
              (Paths.all,
               (if Directory_Names.Is_Empty then Output_Path else Source_Path),
               Names.all,
               Status => Status);
            Free_Text_Array (Paths);
            Free_Text_Array (Names);
         exception
            when others =>
               Free_Text_Array (Paths);
               Free_Text_Array (Names);
               raise;
         end;
         if Status /= Zlib.Ok or else Directory_Names.Is_Empty then
            return;
         end if;
         Status := Zlib.Input_File_Error;
         IO.Open (Source, IO.In_File, Source_Path);
         IO.Set_Index (Source, IO.Size (Source) - 21);
         IO.Read (Source, End_Record, Last);
         if Last /= End_Record'Last or else Number (1, 4) /= 16#0605_4B50#
           or else Number (11, 2) /= U32 (File_Paths.Length) or else Number (21, 2) /= 0
         then
            raise IO.Data_Error;
         end if;
         Central_Size := Number (13, 4);
         Central_Offset := Number (17, 4);
         if IO.Count (Central_Offset) + IO.Count (Central_Size) + 22 /= IO.Size (Source) then
            raise IO.Data_Error;
         end if;
         IO.Set_Index (Source, 1);
      end if;

      Status := Zlib.Output_File_Error;
      IO.Create (Output, IO.Out_File, Output_Path);
      if IO.Is_Open (Source) then
         Copy (Central_Offset);
      end if;
      declare
         Locations : U32_Array_Access := null;
         Catalog_Offset, Catalog_Size : U32;
      begin
         Locations := new U32_Array (1 .. Natural (Directory_Names.Length));
         for I in Locations.all'Range loop
            if Files.Job_Context.Cancelled then
               raise IO.Use_Error;
            end if;
            Locations.all (I) := Offset;
            Put (16#0403_4B50#, 4);
            Put (20, 2);
            Put (16#0800#, 2); --  UTF-8 member name
            for Field in 1 .. 3 loop
               Put (0, 2); --  Stored method and deterministic timestamps
            end loop;
            for Field in 1 .. 3 loop
               Put (0, 4); --  CRC and payload sizes of an empty directory
            end loop;
            Put (U32 (Length (Directory_Names (I))), 2);
            Put (0, 2);
            Put_Name (To_String (Directory_Names (I)));
         end loop;
         Catalog_Offset := Offset;
         if IO.Is_Open (Source) then
            Copy (Central_Size);
         end if;
         for I in Locations.all'Range loop
            Put (16#0201_4B50#, 4);
            Put (20, 2);
            Put (20, 2);
            Put (16#0800#, 2);
            for Field in 1 .. 3 loop
               Put (0, 2);
            end loop;
            for Field in 1 .. 3 loop
               Put (0, 4);
            end loop;
            Put (U32 (Length (Directory_Names (I))), 2);
            for Field in 1 .. 4 loop
               Put (0, 2); --  Extra, comment, disk and internal attributes
            end loop;
            Put (16#10#, 4); --  DOS directory attribute
            Put (Locations.all (I), 4);
            Put_Name (To_String (Directory_Names (I)));
         end loop;
         Catalog_Size := Offset - Catalog_Offset;
         Put (16#0605_4B50#, 4);
         Put (0, 2);
         Put (0, 2);
         Put (U32 (Input_Paths'Length), 2);
         Put (U32 (Input_Paths'Length), 2);
         Put (Catalog_Size, 4);
         Put (Catalog_Offset, 4);
         Put (0, 2);
         Free_U32_Array (Locations);
      exception
         when others =>
            Free_U32_Array (Locations);
            raise;
      end;
      Close (Source);
      Close (Output);
      --  The archive is complete. Removing the intermediate file is best
      --  effort -- the caller's staging folder goes anyway -- and must not
      --  turn a finished archive into a reported failure.
      Status := Zlib.Ok;
      if not File_Paths.Is_Empty then
         begin
            Ada.Directories.Delete_File (Source_Path);
         exception
            when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
               null;
         end;
      end if;
   exception
      when others =>
         Close (Source);
         Close (Output);
   end ZIP_Files;
end Files.Archive_Writing;
