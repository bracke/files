with Files.Diagnostics;
with Ada.Containers;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;
with Ada.Streams;
with GNAT.OS_Lib;
with Files.Bounded_Streams;
with Files.Durable_Writes;
with Files.File_Identities;
with Files.Lease_Streams;
with Files.Private_Directories;
with Hostkit.Fs;
with Hostkit.Lease_Files;

package body Files.Copy_Context is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Hostkit.Lease_Files.Open_Outcome;

   Links_Header : constant String := "files-copy-links-1";
   Max_Links_File_Bytes : constant := 64 * 1024 * 1024;
   Max_Link_Fields : constant := 1_000_000;
   Max_Link_Field_Length : constant := 32 * 1024;

   type Descriptor_Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   end record;

   overriding procedure Read
     (Stream : in out Descriptor_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Descriptor_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

   overriding procedure Read
     (Stream : in out Descriptor_Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Stream, Item, Last);
   begin
      raise Program_Error;
   end Read;

   overriding procedure Write
     (Stream : in out Descriptor_Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array)
   is
      Next    : Ada.Streams.Stream_Element_Offset := Item'First;
      Written : Integer;
   begin
      while Next <= Item'Last loop
         Written := GNAT.OS_Lib.Write
           (Stream.Descriptor, Item (Next)'Address,
            Integer (Item'Last - Next + 1));
         if Written <= 0 then
            raise Ada.Directories.Use_Error;
         end if;
         Next := Next + Ada.Streams.Stream_Element_Offset (Written);
      end loop;
   end Write;

   function Valid_Batch_Directory (Path : String) return Boolean is
   begin
      if Path = "" or else Path'Length > Max_Link_Field_Length then
         return False;
      end if;
      for Item of Path loop
         if Item = ASCII.NUL then
            return False;
         end if;
      end loop;
      return GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others =>
         return False;
   end Valid_Batch_Directory;

   function Create return Session is
      Result : Session;
   begin
      Files.Process_Jobs.Reserve (Result.Job);
      return Result;
   end Create;

   function Directory (Batch : Session) return String is
     (if Length (Batch.Borrowed) > 0 then To_String (Batch.Borrowed)
      else Files.Process_Jobs.Path (Batch.Job, ""));

   function Borrow (Path : String) return Session is
   begin
      if not Valid_Batch_Directory (Path) then
         raise Ada.Directories.Use_Error;
      end if;
      return (Job => <>, Borrowed => To_Unbounded_String (Path));
   end Borrow;

   function Records (Batch : Session) return Files.Types.String_Vectors.Vector is
      Result : Files.Types.String_Vectors.Vector;
      Input : aliased Files.Lease_Streams.Input_Stream;
      Batch_Directory : constant String := Directory (Batch);
      Path : constant String :=
        (if Batch_Directory = "" then ""
         else Hostkit.Fs.Join (Batch_Directory, "links"));
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return Result;
      end if;
      if Hostkit.Fs.Is_Link (Batch_Directory)
        or else not Ada.Directories.Exists (Batch_Directory)
        or else Ada.Directories.Kind (Batch_Directory) /= Ada.Directories.Directory
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      if Files.Lease_Streams.Open (Path, Input) /=
        Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) >
          Long_Long_Integer (Max_Links_File_Bytes)
        or else Files.Bounded_Streams.Input_String
          (Input'Access, Links_Header'Length) /= Links_Header
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      declare
         Count : constant Natural :=
           Natural'Input (Input'Access);
      begin
         if Count > Max_Link_Fields then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         for Index in 1 .. Count loop
            Result.Append
              (To_Unbounded_String
                 (Files.Bounded_Streams.Input_String
                    (Input'Access, Max_Link_Field_Length)));
         end loop;
      end;
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return Result;
   exception
      when others =>
         Files.Lease_Streams.Release (Input);
         raise;
   end Records;

   procedure Save (Batch : Session; Items : Files.Types.String_Vectors.Vector) is
      Batch_Directory : constant String := Directory (Batch);
      Path : constant String :=
        (if Batch_Directory = "" then ""
         else Hostkit.Fs.Join (Batch_Directory, "links"));
      Temp : constant String :=
        (if Batch_Directory = "" then ""
         else Hostkit.Fs.Join (Batch_Directory, "links.tmp"));
      --  Attribute encodings have a small implementation-defined overhead.
      --  Charge a conservative 16 bytes per string and enough for the header
      --  and vector count so the writer cannot create a journal its reader
      --  must reject for exceeding Max_Links_File_Bytes.
      Total : Natural := Links_Header'Length + 32;
      Output : aliased Descriptor_Output_Stream :=
        (Ada.Streams.Root_Stream_Type with
         Descriptor => GNAT.OS_Lib.Invalid_FD);
      Temp_Identity : Unbounded_String;

      procedure Remove_Owned_Temp is
      begin
         if Length (Temp_Identity) > 0
           and then Files.File_Identities.Token (Temp) =
             To_String (Temp_Identity)
         then
            Ada.Directories.Delete_File (Temp);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Copy_Context");
      end Remove_Owned_Temp;
   begin
      if Path = "" then
         return;
      end if;
      if Hostkit.Fs.Is_Link (Batch_Directory)
        or else not Ada.Directories.Exists (Batch_Directory)
        or else Ada.Directories.Kind (Batch_Directory) /= Ada.Directories.Directory
        or else Hostkit.Fs.Is_Link (Path)
        or else (Ada.Directories.Exists (Path)
          and then Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File)
        or else Hostkit.Fs.Is_Link (Temp)
        or else Ada.Directories.Exists (Temp)
      then
         raise Ada.Directories.Use_Error;
      end if;
      if Items.Length > Ada.Containers.Count_Type (Max_Link_Fields) then
         raise Ada.Directories.Use_Error;
      end if;
      for Item of Items loop
         if Length (Item) > Max_Link_Field_Length
           or else Length (Item) + 16 > Max_Links_File_Bytes - Total
         then
            raise Ada.Directories.Use_Error;
         end if;
         Total := Total + Length (Item) + 16;
      end loop;
      Output.Descriptor :=
        GNAT.OS_Lib.Create_New_File (Temp, GNAT.OS_Lib.Binary);
      if Output.Descriptor = GNAT.OS_Lib.Invalid_FD then
         raise Ada.Directories.Use_Error;
      end if;
      Temp_Identity := To_Unbounded_String (Files.File_Identities.Token (Temp));
      if Length (Temp_Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Private_Directories.Make_File_Private (Output.Descriptor);
      String'Output (Output'Access, Links_Header);
      Natural'Output (Output'Access, Natural (Items.Length));
      for Item of Items loop
         String'Output (Output'Access, To_String (Item));
      end loop;
      declare
         Closed : Boolean;
      begin
         GNAT.OS_Lib.Close (Output.Descriptor, Closed);
         Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            raise Ada.Directories.Use_Error;
         end if;
      end;
      if Files.File_Identities.Token (Temp) /= To_String (Temp_Identity) then
         raise Ada.Directories.Use_Error;
      end if;
      if not Files.Durable_Writes.Published
        (Files.Durable_Writes.Publish (Temp, Path))
      then
         raise Ada.Directories.Use_Error;
      end if;
      Temp_Identity := Null_Unbounded_String;
   exception
      when others =>
         if Output.Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Output.Descriptor);
            Output.Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         Remove_Owned_Temp;
         raise;
   end Save;
end Files.Copy_Context;
