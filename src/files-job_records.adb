with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Interfaces;

with Files.Bounded_Streams;
with Files.Shared_Bytes;
with Files.Types;

package body Files.Job_Records is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Ada.Streams.Stream_Element_Offset;

   Max_Settings_Length : constant := 1 * 1024 * 1024;
   --  Matches the per-directory listing cap; the transport byte limit bounds
   --  what a real record can hold.
   Max_Item_Count : constant := 1_000_000;
   --  Items reserved up front before any are read, so a forged count cannot
   --  force a large allocation; a genuine long listing grows past it.
   Max_Item_Reserve : constant := 10_000;
   Max_Argument_Count : constant := 256;
   Max_Thumbnail_Dimension : constant := 2_048;
   Max_Thumbnail_Bytes : constant := 2_048 * 2_048 * 4;

   function Nul_Free (Value : String) return Boolean is
   begin
      for Item of Value loop
         if Item = ASCII.NUL then
            return False;
         end if;
      end loop;
      return True;
   end Nul_Free;

   function Valid_Absolute_Path
     (Value : Files.Types.UString) return Boolean is
      Path : constant String := To_String (Value);
   begin
      return Path /= ""
        and then Nul_Free (Path)
        and then GNAT.OS_Lib.Is_Absolute_Path (Path);
   exception
      when others =>
         return False;
   end Valid_Absolute_Path;

   function Signature_Is_Consistent
     (Value : Files.File_System.Directory_Signature) return Boolean is
   begin
      return Length (Value.Path) = 0
        or else Valid_Absolute_Path (Value.Path);
   end Signature_Is_Consistent;

   function Thumbnail_Is_Valid
     (Value : Files.File_System.Directory_Item) return Boolean
   is
      Pixel_Count : constant Ada.Containers.Count_Type :=
        Ada.Containers.Count_Type (Files.Shared_Bytes.Length (Value.Thumbnail_Pixels));
   begin
      if Value.Thumbnail_Width > Max_Thumbnail_Dimension
        or else Value.Thumbnail_Height > Max_Thumbnail_Dimension
      then
         return False;
      elsif not Value.Thumbnail_Available then
         return Value.Thumbnail_Width = 0
           and then Value.Thumbnail_Height = 0
           and then Pixel_Count = 0;
      end if;

      return Value.Thumbnail_Width > 0
        and then Value.Thumbnail_Height > 0
        and then Pixel_Count =
          Ada.Containers.Count_Type
            (Value.Thumbnail_Width * Value.Thumbnail_Height * 4);
   end Thumbnail_Is_Valid;

   function Item_Is_Consistent
     (Value : Files.File_System.Directory_Item) return Boolean is
   begin
      return Valid_Absolute_Path (Value.Full_Path)
        and then Valid_Absolute_Path (Value.Parent_Path)
        and then Length (Value.Name) > 0
        and then Nul_Free (To_String (Value.Name))
        and then
          (Length (Value.Thumbnail_Path) = 0
           or else Valid_Absolute_Path (Value.Thumbnail_Path))
        and then Thumbnail_Is_Valid (Value)
        and then (not Value.Size_Available or else Value.Size >= 0);
   end Item_Is_Consistent;

   procedure Validate_Size (Size : Long_Long_Integer) is
   begin
      if Size < 0 or else Size > Long_Long_Integer (Max_Transport_Bytes)
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
   end Validate_Size;

   procedure Write_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Maximum : Natural)
   is
   begin
      if Value'Length > Maximum then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Value);
   end Write_String;

   function Read_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Maximum : Natural) return String
   is (Files.Bounded_Streams.Input_String (Stream, Maximum));

   procedure Write_Settings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Settings.Settings_Model)
   is
   begin
      Write_String (Stream, Files.Settings.To_Text (Value), Max_Settings_Length);
   end Write_Settings;

   function Read_Settings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Settings.Settings_Model
   is
      Parsed : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Parse (Read_String (Stream, Max_Settings_Length));
   begin
      if not Parsed.Success then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      return Parsed.Settings;
   end Read_Settings;

   procedure Write_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System.Directory_Signature)
   is
   begin
      if not Signature_Is_Consistent (Value) then
         raise Ada.Directories.Use_Error;
      end if;
      Write_String (Stream, To_String (Value.Path), Max_Path_Length);
      Boolean'Output (Stream, Value.Exists);
      Natural'Output (Stream, Value.Entry_Count);
      Natural'Output (Stream, Value.Entry_State_Checksum);
      Ada.Calendar.Time'Output (Stream, Value.Latest_Modified);
      Boolean'Output (Stream, Value.Latest_Modified_Known);
   end Write_Signature;

   function Read_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System.Directory_Signature
   is
      Result : Files.File_System.Directory_Signature;
   begin
      Result.Path := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Exists := Boolean'Input (Stream);
      Result.Entry_Count := Natural'Input (Stream);
      Result.Entry_State_Checksum := Natural'Input (Stream);
      Result.Latest_Modified := Ada.Calendar.Time'Input (Stream);
      Result.Latest_Modified_Known := Boolean'Input (Stream);
      if not Signature_Is_Consistent (Result) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      return Result;
   end Read_Signature;

   --  Thumbnail bytes move through the stream this many at a time.
   Byte_Chunk : constant := 4096;

   procedure Write_Bytes
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Types.Byte_Vectors.Vector)
   is
   begin
      if Value.Length > Ada.Containers.Count_Type (Max_Thumbnail_Bytes) then
         raise Ada.Directories.Use_Error;
      end if;
      Natural'Output (Stream, Natural (Value.Length));
      --  A chunk per call instead of an element per call; the bytes are the
      --  same as Unsigned_8'Output would write.
      declare
         Chunk : Ada.Streams.Stream_Element_Array (1 .. Byte_Chunk);
         Used  : Ada.Streams.Stream_Element_Offset := 0;
      begin
         for Byte of Value loop
            Used := Used + 1;
            Chunk (Used) := Ada.Streams.Stream_Element (Byte);
            if Used = Chunk'Last then
               Stream.Write (Chunk);
               Used := 0;
            end if;
         end loop;
         if Used > 0 then
            Stream.Write (Chunk (1 .. Used));
         end if;
      end;
   end Write_Bytes;

   function Read_Bytes
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Types.Byte_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.Types.Byte_Vectors.Vector;
   begin
      if Count > Max_Thumbnail_Bytes then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Result.Reserve_Capacity (Ada.Containers.Count_Type (Count));
      declare
         Chunk : Ada.Streams.Stream_Element_Array (1 .. Byte_Chunk);
         Left  : Natural := Count;
      begin
         while Left > 0 loop
            declare
               Wanted : constant Ada.Streams.Stream_Element_Offset :=
                 Ada.Streams.Stream_Element_Offset (Natural'Min (Left, Byte_Chunk));
               Filled : Ada.Streams.Stream_Element_Offset := 0;
               Last   : Ada.Streams.Stream_Element_Offset;
            begin
               while Filled < Wanted loop
                  Stream.Read (Chunk (Filled + 1 .. Wanted), Last);
                  if Last <= Filled then
                     raise Ada.IO_Exceptions.End_Error;
                  end if;
                  Filled := Last;
               end loop;
               for Element of Chunk (1 .. Wanted) loop
                  Result.Append (Interfaces.Unsigned_8 (Element));
               end loop;
               Left := Left - Natural (Wanted);
            end;
         end loop;
      end;
      return Result;
   end Read_Bytes;

   procedure Write_Item
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System.Directory_Item)
   is
   begin
      if not Item_Is_Consistent (Value) then
         raise Ada.Directories.Use_Error;
      end if;
      Write_String (Stream, To_String (Value.Name), Max_Path_Length);
      Write_String (Stream, To_String (Value.Full_Path), Max_Path_Length);
      Write_String (Stream, To_String (Value.Parent_Path), Max_Path_Length);
      Boolean'Output (Stream, Value.Hidden);
      Files.Types.Item_Kind'Output (Stream, Value.Kind);
      Write_String (Stream, To_String (Value.Filetype), Max_Text_Length);
      Write_String (Stream, To_String (Value.Icon_Id), Max_Text_Length);
      Boolean'Output (Stream, Value.Size_Available);
      Long_Long_Integer'Output (Stream, Value.Size);
      Boolean'Output (Stream, Value.Creation_Available);
      Ada.Calendar.Time'Output (Stream, Value.Creation_Time);
      Boolean'Output (Stream, Value.Modified_Available);
      Ada.Calendar.Time'Output (Stream, Value.Modified_Time);
      Write_String (Stream, To_String (Value.Permissions), Max_Text_Length);
      Boolean'Output (Stream, Value.Mode_Available);
      Natural'Output (Stream, Value.Mode_Bits);
      Boolean'Output (Stream, Value.Ownership_Available);
      Files.Types.Account_Id'Output (Stream, Value.Owner_Id);
      Files.Types.Account_Id'Output (Stream, Value.Group_Id);
      Write_String (Stream, To_String (Value.Filetype_Extra), Max_Text_Length);
      Boolean'Output (Stream, Value.Filetype_Extra_Loaded);
      Boolean'Output (Stream, Value.Thumbnail_Available);
      Write_String (Stream, To_String (Value.Thumbnail_Path), Max_Path_Length);
      Natural'Output (Stream, Value.Thumbnail_Width);
      Natural'Output (Stream, Value.Thumbnail_Height);
      Write_Bytes (Stream, Files.Shared_Bytes.To_Vector (Value.Thumbnail_Pixels));
      Boolean'Output (Stream, Value.Metadata_Error);
      Write_String (Stream, To_String (Value.Error_Key), Max_Error_Length);
   end Write_Item;

   function Read_Item
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System.Directory_Item
   is
      Result : Files.File_System.Directory_Item;
   begin
      Result.Name := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Full_Path := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Parent_Path := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Hidden := Boolean'Input (Stream);
      Result.Kind := Files.Types.Item_Kind'Input (Stream);
      Result.Filetype := To_Unbounded_String (Read_String (Stream, Max_Text_Length));
      Result.Icon_Id := To_Unbounded_String (Read_String (Stream, Max_Text_Length));
      Result.Size_Available := Boolean'Input (Stream);
      Result.Size := Long_Long_Integer'Input (Stream);
      Result.Creation_Available := Boolean'Input (Stream);
      Result.Creation_Time := Ada.Calendar.Time'Input (Stream);
      Result.Modified_Available := Boolean'Input (Stream);
      Result.Modified_Time := Ada.Calendar.Time'Input (Stream);
      Result.Permissions := To_Unbounded_String (Read_String (Stream, Max_Text_Length));
      Result.Mode_Available := Boolean'Input (Stream);
      Result.Mode_Bits := Natural'Input (Stream);
      Result.Ownership_Available := Boolean'Input (Stream);
      Result.Owner_Id := Files.Types.Account_Id'Input (Stream);
      Result.Group_Id := Files.Types.Account_Id'Input (Stream);
      Result.Filetype_Extra := To_Unbounded_String (Read_String (Stream, Max_Text_Length));
      Result.Filetype_Extra_Loaded := Boolean'Input (Stream);
      Result.Thumbnail_Available := Boolean'Input (Stream);
      Result.Thumbnail_Path := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Thumbnail_Width := Natural'Input (Stream);
      Result.Thumbnail_Height := Natural'Input (Stream);
      Result.Thumbnail_Pixels := Files.Shared_Bytes.To_Shared (Read_Bytes (Stream));
      Result.Metadata_Error := Boolean'Input (Stream);
      Result.Error_Key := To_Unbounded_String (Read_String (Stream, Max_Error_Length));
      if not Item_Is_Consistent (Result) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      return Result;
   end Read_Item;

   procedure Write_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System.Item_Vectors.Vector)
   is
   begin
      if Value.Length > Ada.Containers.Count_Type (Max_Item_Count) then
         raise Ada.Directories.Use_Error;
      end if;
      Natural'Output (Stream, Natural (Value.Length));
      for Item of Value loop
         Write_Item (Stream, Item);
      end loop;
   end Write_Items;

   function Read_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System.Item_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.File_System.Item_Vectors.Vector;
   begin
      if Count > Max_Item_Count then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      Result.Reserve_Capacity (Ada.Containers.Count_Type (Natural'Min (Count, Max_Item_Reserve)));
      for Index in 1 .. Count loop
         Result.Append (Read_Item (Stream));
      end loop;
      return Result;
   end Read_Items;

   procedure Write_Strings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Types.String_Vectors.Vector)
   is
   begin
      if Value.Length > Ada.Containers.Count_Type (Max_Argument_Count) then
         raise Ada.Directories.Use_Error;
      end if;
      Natural'Output (Stream, Natural (Value.Length));
      for Item of Value loop
         Write_String (Stream, To_String (Item), Max_Text_Length);
      end loop;
   end Write_Strings;

   function Read_Strings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Types.String_Vectors.Vector
   is
      Count : constant Natural := Natural'Input (Stream);
      Result : Files.Types.String_Vectors.Vector;
   begin
      if Count > Max_Argument_Count then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      for Index in 1 .. Count loop
         Result.Append (To_Unbounded_String (Read_String (Stream, Max_Text_Length)));
      end loop;
      return Result;
   end Read_Strings;

   function Action_Metadata_Is_Consistent
     (Value : Files.Operations.Operation_Result) return Boolean
   is
     (Value.Action.Arguments.Length <=
        Ada.Containers.Count_Type (Max_Argument_Count)
      and then Value.Action_Executable = Value.Action.Executable
      and then Value.Action_Arguments = Natural (Value.Action.Arguments.Length)
      and then Value.Action_Uses_Shell = Value.Action.Use_Shell);

   procedure Write_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Operations.Operation_Result)
   is
   begin
      if not Action_Metadata_Is_Consistent (Value) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Operations.Operation_Status'Output (Stream, Value.Status);
      Write_String (Stream, To_String (Value.Error_Key), Max_Error_Length);
      Write_String (Stream, To_String (Value.Path), Max_Path_Length);
      Write_String (Stream, To_String (Value.Action.Executable), Max_Path_Length);
      Write_Strings (Stream, Value.Action.Arguments);
      Boolean'Output (Stream, Value.Action.Use_Shell);
      Write_String (Stream, To_String (Value.Action_Executable), Max_Path_Length);
      Natural'Output (Stream, Value.Action_Arguments);
      Boolean'Output (Stream, Value.Action_Uses_Shell);
      Boolean'Output (Stream, Value.Execution_Attempted);
      Boolean'Output (Stream, Value.Executable_Found);
      Boolean'Output (Stream, Value.Exit_Status_Known);
      Integer'Output (Stream, Value.Exit_Status);
   end Write_Operation_Result;

   function Read_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Operations.Operation_Result
   is
      Result : Files.Operations.Operation_Result;
   begin
      Result.Status := Files.Operations.Operation_Status'Input (Stream);
      Result.Error_Key := To_Unbounded_String (Read_String (Stream, Max_Error_Length));
      Result.Path := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Action.Executable := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Action.Arguments := Read_Strings (Stream);
      Result.Action.Use_Shell := Boolean'Input (Stream);
      Result.Action_Executable := To_Unbounded_String (Read_String (Stream, Max_Path_Length));
      Result.Action_Arguments := Natural'Input (Stream);
      Result.Action_Uses_Shell := Boolean'Input (Stream);
      Result.Execution_Attempted := Boolean'Input (Stream);
      Result.Executable_Found := Boolean'Input (Stream);
      Result.Exit_Status_Known := Boolean'Input (Stream);
      Result.Exit_Status := Integer'Input (Stream);
      if not Action_Metadata_Is_Consistent (Result) then
         raise Ada.IO_Exceptions.Data_Error;
      end if;
      return Result;
   end Read_Operation_Result;
end Files.Job_Records;
