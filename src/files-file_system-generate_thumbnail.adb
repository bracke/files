separate (Files.File_System)
function Generate_Thumbnail
  (Source_Path      : String;
   Cache_Directory : String;
   Size            : Positive := 64)
   return Thumbnail_Result
is
   File : Stream_IO.File_Type;
   Temp : Unbounded_String;
   Temp_Identity : Unbounded_String;

   procedure Remove_Owned_Temp is
   begin
      if Length (Temp) > 0
        and then Length (Temp_Identity) > 0
        and then Files.File_Identities.Token (To_String (Temp)) = To_String (Temp_Identity)
        and then Ada.Directories.Exists (To_String (Temp))
      then
         Ada.Directories.Delete_File (To_String (Temp));
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
   end Remove_Owned_Temp;

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
      when others =>
         return False;
   end Publish_Temp;

begin
   if Size > Max_Thumbnail_Dimension then
      return
        (Status         => Thumbnail_Failed,
         Source_Path    => To_Unbounded_String (Source_Path),
         Thumbnail_Path => Null_Unbounded_String,
         Width          => Size,
         Height         => Size,
         Error_Key      => To_Unbounded_String ("error.thumbnail.failed"));
   end if;

   if not Ada.Directories.Exists (Source_Path) then
      return
        (Status         => Thumbnail_Source_Missing,
         Source_Path    => To_Unbounded_String (Source_Path),
         Thumbnail_Path => Null_Unbounded_String,
         Width          => Size,
         Height         => Size,
         Error_Key      => To_Unbounded_String ("error.thumbnail.source_missing"));
   elsif Ada.Directories.Kind (Source_Path) /= Ada.Directories.Ordinary_File then
      return
        (Status         => Thumbnail_Unsupported,
         Source_Path    => To_Unbounded_String (Source_Path),
         Thumbnail_Path => Null_Unbounded_String,
         Width          => Size,
         Height         => Size,
         Error_Key      => To_Unbounded_String ("error.thumbnail.unsupported"));
   end if;

   Ada.Directories.Create_Path
     (Ada.Directories.Containing_Directory (Cache_Directory));
   Files.Private_Directories.Ensure (Cache_Directory);
   Prune_Cache_Once (Cache_Directory);
   Target := To_Unbounded_String (Thumbnail_Path_For (Source_Path, Cache_Directory, Size));
   declare
      use type GNAT.OS_Lib.File_Descriptor;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   begin
      for Index in 1 .. 9_999 loop
         declare
            Candidate : constant String := To_String (Target) & ".tmp"
              & (if Index = 1 then "" else "-" &
                   Ada.Strings.Fixed.Trim (Positive'Image (Index), Ada.Strings.Both));
         begin
            Descriptor := GNAT.OS_Lib.Create_New_File (Candidate, GNAT.OS_Lib.Binary);
            if Descriptor /= GNAT.OS_Lib.Invalid_FD then
               Temp := To_Unbounded_String (Candidate);
               Temp_Identity := To_Unbounded_String (Files.File_Identities.Token (Candidate));
               if Length (Temp_Identity) = 0 then
                  raise Ada.Directories.Use_Error;
               end if;
               Files.Private_Directories.Make_File_Private (Descriptor);
               GNAT.OS_Lib.Close (Descriptor);
               Descriptor := GNAT.OS_Lib.Invalid_FD;
               exit;
            end if;
         end;
      end loop;
      if Descriptor /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (Descriptor);
      end if;
      if Length (Temp_Identity) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         raise;
   end;
   if (Source_Fits_Fast_Decode (Source_Path)
       and then (Try_Write_Decoded_Png_Thumbnail (Source_Path, Size, To_String (Temp))
                 or else Try_Write_Decoded_P3_Thumbnail (Source_Path, Size, To_String (Temp))))
     or else Try_Write_Gdk_Pixbuf_Thumbnail (Source_Path, Size, To_String (Temp))
   then
      if Publish_Temp (To_String (Target)) then
         return
           (Status         => Thumbnail_Generated,
            Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => Null_Unbounded_String);
      end if;
      raise Ada.Directories.Use_Error;
   end if;

   Checksum := Thumbnail_Path_Checksum (Source_Path);
   Size_Bias := File_Size_Signal (Source_Path);

   --  The deterministic stand-in, written in the same binary P6 the decoded
   --  thumbnails use, through Stream_IO for the same reason: -gnatW8 would
   --  have Text_IO re-encode every byte above 127 on the way out.
   declare
      use Ada.Streams;

      Row_Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size) * 3);

      procedure Put_Header (Text : String) is
         Buffer : Stream_Element_Array (1 .. Text'Length);
      begin
         for Index in Text'Range loop
            Buffer (Stream_Element_Offset (Index - Text'First + 1)) :=
              Stream_Element (Character'Pos (Text (Index)));
         end loop;

         Stream_IO.Write (File, Buffer);
      end Put_Header;
   begin
      Stream_IO.Create (File, Stream_IO.Out_File, To_String (Temp), Form => "shared=no");
      Put_Header
        ("P6" & ASCII.LF
         & Image_No_Space (Size) & " " & Image_No_Space (Size) & ASCII.LF
         & "255" & ASCII.LF);

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

         Stream_IO.Write (File, Row_Bytes);
      end loop;

      Stream_IO.Close (File);
   end;

   if not Publish_Temp (To_String (Target)) then
      raise Ada.Directories.Use_Error;
   end if;

   return
     (Status         => Thumbnail_Generated,
      Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
      Thumbnail_Path => Target,
      Width          => Size,
      Height         => Size,
      Error_Key      => Null_Unbounded_String);
exception
   when others =>
      if Stream_IO.Is_Open (File) then
         Stream_IO.Close (File);
      end if;
      Remove_Owned_Temp;

      return
        (Status         => Thumbnail_Failed,
         Source_Path    => To_Unbounded_String (Source_Path),
         Thumbnail_Path => Target,
         Width          => Size,
         Height         => Size,
         Error_Key      => To_Unbounded_String ("error.thumbnail.failed"));
end Generate_Thumbnail;
