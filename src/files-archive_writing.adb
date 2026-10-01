with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Interfaces;
with Files.Job_Context;
with Files.Types;

package body Files.Archive_Writing is
   use Ada.Strings.Unbounded;
   use Ada.Streams;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_IO.Count;
   use type Interfaces.Unsigned_32;
   use type Zlib.Status_Code;

   procedure ZIP_Files
     (Input_Paths : Zlib.Text_Array;
      Output_Path : String;
      Entry_Names : Zlib.Text_Array;
      Status : out Zlib.Status_Code)
   is
      package IO renames Ada.Streams.Stream_IO;
      subtype U32 is Interfaces.Unsigned_32;
      Source, Output : IO.File_Type;
      File_Paths, File_Names, Directory_Names : Files.Types.String_Vectors.Vector;
      Source_Path : constant String := Output_Path & ".files";
      Central_Offset, Central_Size : U32 := 0;
      End_Record : Stream_Element_Array (1 .. 22);
      Last : Stream_Element_Offset;

      function Safe_Name (Name : String) return Boolean is
         First : Positive := Name'First;
      begin
         if Name = "" then
            return False;
         end if;
         for I in Name'Range loop
            if Name (I) = ASCII.NUL or else Name (I) = '\' or else Name (I) = ':' then
               return False;
            elsif Name (I) = '/' then
               if I = First or else Name (First .. I - 1) in "." | ".." then
                  return False;
               end if;
               First := I + 1;
            end if;
         end loop;
         return First <= Name'Last and then Name (First .. Name'Last) not in "." | "..";
      end Safe_Name;

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
            if not Safe_Name (Name) or else Name'Length >= 65_535 then
               return;
            end if;
            for Previous in 0 .. I - 1 loop
               if Entry_Names (Entry_Names'First + Previous) = Entry_Names (Entry_Names'First + I) then
                  return;
               end if;
            end loop;
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
            Paths, Names : Zlib.Text_Array (1 .. Natural (File_Paths.Length));
         begin
            for I in Paths'Range loop
               Paths (I) := File_Paths (I);
               Names (I) := File_Names (I);
            end loop;
            Zlib.ZIP_Files (Paths, (if Directory_Names.Is_Empty then Output_Path else Source_Path), Names,
                            Status => Status);
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
         Locations : array (1 .. Natural (Directory_Names.Length)) of U32;
         Catalog_Offset, Catalog_Size : U32;
      begin
         for I in Locations'Range loop
            if Files.Job_Context.Cancelled then
               raise IO.Use_Error;
            end if;
            Locations (I) := Offset;
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
         for I in Locations'Range loop
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
            Put (Locations (I), 4);
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
      end;
      Close (Source);
      Close (Output);
      if not File_Paths.Is_Empty then
         Ada.Directories.Delete_File (Source_Path);
      end if;
      Status := Zlib.Ok;
   exception
      when others =>
         Close (Source);
         Close (Output);
   end ZIP_Files;
end Files.Archive_Writing;
