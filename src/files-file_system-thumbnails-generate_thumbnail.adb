with Files.Fs_Primitives;
with Files.Images.Netpbm;
with Files.Durable_Writes;

separate (Files.File_System.Thumbnails)
function Generate_Thumbnail
  (Source_Path      : String;
   Cache_Directory : String;
   Size            : Positive := 64)
   return Thumbnail_Result
is
   --  Locals, not package state: listings on the refresh tasks and the
   --  Generate Thumbnails command on the UI thread run this at once.
   Target        : Unbounded_String;
   Temp          : Unbounded_String;
   Temp_Identity : Unbounded_String;
   Checksum      : Natural;
   Size_Bias     : Natural;

   function Failed (Status : Thumbnail_Status; Error_Key : String) return Thumbnail_Result is
     (Status         => Status,
      Source_Path    => To_Unbounded_String (Source_Path),
      Thumbnail_Path => Target,
      Width          => Size,
      Height         => Size,
      Error_Key      => To_Unbounded_String (Error_Key));

   function Generated return Thumbnail_Result is
     (Status         => Thumbnail_Generated,
      Source_Path    => To_Unbounded_String (Files.Fs_Primitives.Full_Name (Source_Path)),
      Thumbnail_Path => Target,
      Width          => Size,
      Height         => Size,
      Error_Key      => Null_Unbounded_String);

   --  Nothing yet: the thumbnail is written into the reserved file later.
   procedure Write_Nothing (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is null;

   --  The deterministic stand-in, in the same binary P6 the decoded
   --  thumbnails use: a checkerboard tinted by the source's path and size.
   procedure Write_Stand_In (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      use Ada.Streams;

      Row_Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size) * 3);
   begin
      Stream.Write (Files.Images.Netpbm.P6_Header (Size, Size));

      for Row in 0 .. Size - 1 loop
         for Column in 0 .. Size - 1 loop
            declare
               Cell    : constant Natural := Natural'Max (1, Size / 8);
               Stripe  : constant Natural := (Row / Cell + Column / Cell) mod 2;
               Red     : constant Natural := Clamp_Channel (Checksum + Row * 5 + Size_Bias / 7 + Stripe * 28);
               Green   : constant Natural := Clamp_Channel (Checksum / 257 + Column * 7 + Size_Bias / 11);
               Blue    : constant Natural := Clamp_Channel (Checksum / 65_521 + Row + Column * 3 + Size_Bias / 13);
               At_Byte : constant Stream_Element_Offset := Stream_Element_Offset (Column) * 3 + 1;
            begin
               Row_Bytes (At_Byte)     := Stream_Element (Red mod 256);
               Row_Bytes (At_Byte + 1) := Stream_Element (Green mod 256);
               Row_Bytes (At_Byte + 2) := Stream_Element (Blue mod 256);
            end;
         end loop;

         Stream.Write (Row_Bytes);
      end loop;
   end Write_Stand_In;

   function Publish_Temp (Target_Path : String) return Boolean is
   begin
      if Length (Temp_Identity) = 0
        or else Files.File_Identities.Token (To_String (Temp)) /= To_String (Temp_Identity)
        or else not Hostkit.Fs.Replace_File (To_String (Temp), Target_Path)
      then
         return False;
      end if;
      Temp := Null_Unbounded_String;
      Temp_Identity := Null_Unbounded_String;
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         return False;
   end Publish_Temp;

begin
   if Size > Max_Thumbnail_Dimension then
      return Failed (Thumbnail_Failed, "error.thumbnail.failed");
   --  refusal-safe: a source not seen gets no thumbnail; only the words
   --  of the failure depend on why.
   elsif not Files.Fs_Primitives.Exists (Source_Path) then
      return Failed (Thumbnail_Source_Missing, "error.thumbnail.source_missing");
   elsif Files.Fs_Primitives.Kind (Source_Path) /= Ada.Directories.Ordinary_File then
      return Failed (Thumbnail_Unsupported, "error.thumbnail.unsupported");
   end if;

   Files.Fs_Primitives.Create_Path (Files.Fs_Primitives.Parent_Directory (Cache_Directory));
   Files.Private_Directories.Ensure (Cache_Directory);
   Prune_Cache_Once (Cache_Directory);
   Target := To_Unbounded_String (Thumbnail_Path_For (Source_Path, Cache_Directory, Size));
   --  A private temporary reserved beside the target, written below by
   --  name by a decoder.
   Files.Durable_Writes.Write_Private_Temporary (To_String (Target), Write_Nothing'Access, Temp, Temp_Identity);
   if (Source_Fits_Fast_Decode (Source_Path)
       and then (Try_Write_Decoded_Png_Thumbnail (Source_Path, Size, To_String (Temp))
                 or else Try_Write_Decoded_P3_Thumbnail (Source_Path, Size, To_String (Temp))))
     or else Try_Write_Gdk_Pixbuf_Thumbnail (Source_Path, Size, To_String (Temp))
   then
      if Publish_Temp (To_String (Target)) then
         return Generated;
      end if;
      raise Ada.Directories.Use_Error;
   end if;

   Checksum := Thumbnail_Path_Checksum (Source_Path);
   Size_Bias := File_Size_Signal (Source_Path);

   --  No decoder took it: the deterministic stand-in replaces whatever a
   --  decoder left in the temporary, written through the same helper so a
   --  disk that will not take it is cleaned up there.
   Files.Durable_Writes.Remove_Owned (To_String (Temp), To_String (Temp_Identity));
   Temp := Null_Unbounded_String;
   Temp_Identity := Null_Unbounded_String;
   Files.Durable_Writes.Write_Private_Temporary (To_String (Target), Write_Stand_In'Access, Temp, Temp_Identity);

   if not Publish_Temp (To_String (Target)) then
      raise Ada.Directories.Use_Error;
   end if;

   return Generated;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      Files.Durable_Writes.Remove_Owned (To_String (Temp), To_String (Temp_Identity));
      return Failed (Thumbnail_Failed, "error.thumbnail.failed");
end Generate_Thumbnail;
