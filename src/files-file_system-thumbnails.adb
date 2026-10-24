with Files.Diagnostics;
with Files.File_System.Support;
with Files.Private_Directories;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Directories;
with Ada.Characters;
with Ada.Streams;
with System;
with System.Address_To_Access_Conversions;
with Files.File_Types;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Ada.Characters.Handling;
with Ada.Containers.Ordered_Sets;
with Ada.Unchecked_Deallocation;
with CryptoLib.Hashes;
with GNAT.CRC32;
with Zlib;

separate (Files.File_System)
package body Thumbnails is

   --  The largest source image decoded for a thumbnail: each side, and the
   --  whole (2048 x 2048), so a hostile header cannot ask for gigabytes.
   Max_Source_Side   : constant := 4096;
   Max_Source_Pixels : constant := 4_194_304;
   package Stream_IO renames Ada.Streams.Stream_IO;

   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Directories.File_Kind;

   use type Files.Types.Item_Kind;
   use type System.Address;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   Max_Thumbnail_Dimension : constant Positive := 2_048;
   Max_Decode_Source_Bytes : constant Natural := 128 * 1024 * 1024;

   function Loader_New return System.Address
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_new";

   function Loader_Write
     (Loader : System.Address;
      Buffer : System.Address;
      Count  : Interfaces.C.size_t;
      Error  : System.Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_write";

   function Loader_Close
     (Loader : System.Address;
      Error  : System.Address)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_close";

   function Loader_Get_Pixbuf (Loader : System.Address) return System.Address
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_get_pixbuf";

   procedure Loader_Set_Size
     (Loader : System.Address; Width, Height : C_Int)
     with Import, Convention => C, External_Name => "gdk_pixbuf_loader_set_size";

   function Signal_Connect_Data
     (Instance        : System.Address;
      Detailed_Signal : Interfaces.C.Strings.chars_ptr;
      Handler         : System.Address;
      Data            : System.Address;
      Destroy_Data    : System.Address;
      Flags           : Interfaces.C.int) return Interfaces.C.unsigned_long
     with Import, Convention => C, External_Name => "g_signal_connect_data";

   function Gdk_Pixbuf_Get_Width
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_width";

   function Gdk_Pixbuf_Get_Height
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_height";

   function Gdk_Pixbuf_Get_N_Channels
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_n_channels";

   function Gdk_Pixbuf_Get_Rowstride
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_rowstride";

   function Gdk_Pixbuf_Get_Pixels
     (Pixbuf : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_pixels";

   procedure G_Object_Unref
     (Object : System.Address)
   with Import, Convention => C, External_Name => "g_object_unref";

   package C_Int_Pointers is new System.Address_To_Access_Conversions (C_Int);
   use type C_Int_Pointers.Object_Pointer;

   procedure Loader_Size_Prepared
     (Loader : System.Address;
      Width, Height : C_Int;
      Data : System.Address)
     with Convention => C;

   procedure Loader_Size_Prepared
     (Loader : System.Address;
      Width, Height : C_Int;
      Data : System.Address)
   is
      Limit_Pointer : constant C_Int_Pointers.Object_Pointer :=
        C_Int_Pointers.To_Pointer (Data);
      Target_Width, Target_Height : C_Int;
   begin
      if Limit_Pointer = null
        or else Limit_Pointer.all <= 0
        or else Width <= 0
        or else Height <= 0
      then
         return;
      end if;

      if Width >= Height then
         Target_Width := Limit_Pointer.all;
         Target_Height := C_Int'Max
           (1,
            C_Int
              (Long_Long_Integer (Height) * Long_Long_Integer (Limit_Pointer.all)
               / Long_Long_Integer (Width)));
      else
         Target_Height := Limit_Pointer.all;
         Target_Width := C_Int'Max
           (1,
            C_Int
              (Long_Long_Integer (Width) * Long_Long_Integer (Limit_Pointer.all)
               / Long_Long_Integer (Height)));
      end if;
      Loader_Set_Size (Loader, Target_Width, Target_Height);
   exception
      --  Never let an Ada exception cross the C callback boundary.
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
   end Loader_Size_Prepared;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   function Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural;

   function Thumbnail_Cache_Key
     (Source_Path : String)
      return String;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is
   begin
      if Pointer /= Interfaces.C.Strings.Null_Ptr then
         begin
            Interfaces.C.Strings.Free (Pointer);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         end;
      end if;
   end Safe_Free;

   function Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Name : constant String := Ada.Directories.Simple_Name (Source_Path);
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' and then Index < Name'Last then
            return Files.Types.To_Lower (Name (Index + 1 .. Name'Last));
         end if;
      end loop;

      return "file";
   exception
      when others =>
         return "file";
   end Thumbnail_Extension;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Extension : constant String := Thumbnail_Extension (Source_Path);
      Result    : Unbounded_String;
   begin
      for Value of Extension loop
         if Ada.Characters.Handling.Is_Alphanumeric (Value) then
            Append (Result, Value);
         else
            Append (Result, '_');
         end if;
      end loop;

      if Length (Result) = 0 then
         return "file";
      end if;

      return To_String (Result);
   end Sanitized_Thumbnail_Extension;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Result  : Long_Long_Integer := 0;
   begin
      for Value of Source_Path loop
         Result := (Result * 33 + Long_Long_Integer (Character'Pos (Value))) mod Modulus;
      end loop;

      return Natural (Result);
   end Thumbnail_Path_Checksum;

   function Thumbnail_Cache_Key
     (Source_Path : String)
      return String
   is
      use Ada.Streams;
      Text : constant String :=
        Source_Path & ASCII.NUL
        & Files.File_Identities.Token (Source_Path) & ASCII.NUL
        & Files.File_Identities.Revision (Source_Path);
      Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
      Context : CryptoLib.Hashes.SHA256_Context;
      Digest : CryptoLib.Hashes.SHA256_Digest;
      Hex : constant String := "0123456789abcdef";
      Result : String (1 .. 64);
   begin
      for Index in Text'Range loop
         Data (Stream_Element_Offset (Index - Text'First + 1)) :=
           Stream_Element (Character'Pos (Text (Index)));
      end loop;
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      CryptoLib.Hashes.Update (Context, Data);
      Digest := CryptoLib.Hashes.Finalize (Context);
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1) :=
           Hex (Natural (Digest (Index)) / 16 + 1);
         Result ((Index - Digest'First) * 2 + 2) :=
           Hex (Natural (Digest (Index)) mod 16 + 1);
      end loop;
      return Result;
   end Thumbnail_Cache_Key;

   --  The cache had no bound and nothing ever removed anything from it, so it
   --  accumulated one file per image ever browsed, for as long as the account
   --  existed -- including thumbnails whose source was renamed or deleted long
   --  ago, which nothing could ever match again.
   --
   --  Pruned once per run rather than per write: a directory listing generates
   --  many thumbnails in a row, and scanning the whole cache on each of them
   --  would put a walk of every cached file in the middle of opening a folder.
   --  Once per run keeps growth bounded across sessions and costs one scan.
   --
   --  Oldest first, by modification time, which is also what clears the
   --  orphans: a thumbnail nothing looks at is never rewritten, so it ages out.
   Cache_Byte_Budget : constant Long_Long_Integer := 64 * 1024 * 1024;
   Max_Cache_Prune_Entries : constant Natural := 100_000;

   package Cache_Path_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Unbounded_String);

   Max_Remembered_Cache_Paths : constant Natural := 256;

   protected Cache_Prune_Registry is
      procedure Claim (Path : String; Prune : out Boolean);
   private
      Seen : Cache_Path_Sets.Set;
   end Cache_Prune_Registry;

   protected body Cache_Prune_Registry is
      procedure Claim (Path : String; Prune : out Boolean) is
         Key : constant Unbounded_String := To_Unbounded_String (Path);
      begin
         if Seen.Contains (Key) then
            Prune := False;
         else
            Prune := True;
            --  Keep the registry itself bounded. Beyond the cap, pruning again
            --  is safer than retaining one attacker-controlled path forever.
            if Natural (Seen.Length) < Max_Remembered_Cache_Paths then
               Seen.Insert (Key);
            end if;
         end if;
      end Claim;
   end Cache_Prune_Registry;

   procedure Prune_Thumbnail_Cache
     (Cache_Directory : String;
      Budget_Bytes    : Long_Long_Integer)
   is
      type Cached_File is record
         Path     : Unbounded_String;
         Identity : Unbounded_String;
         Size     : Long_Long_Integer := 0;
         Modified : Ada.Calendar.Time;
      end record;

      package Cached_File_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Cached_File);

      function Older (Left : Cached_File; Right : Cached_File) return Boolean is
        (Left.Modified < Right.Modified);

      function Is_Thumbnail_Name (Name : String) return Boolean is
         Prefix : constant String := "thumb_";
         Suffix : constant String := ".ppm";
         Digest_First : constant Integer := Name'Last - Suffix'Length - 63;
      begin
         return Name'Length >= Prefix'Length + 1 + 1 + 64 + Suffix'Length
           and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
           and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
           and then Name (Digest_First - 1) = '_'
           and then (for all Index in Digest_First .. Digest_First + 63 =>
             Name (Index) in '0' .. '9' | 'a' .. 'f');
      exception
         when others =>
            return False;
      end Is_Thumbnail_Name;

      package Sorting is new Cached_File_Vectors.Generic_Sorting ("<" => Older);

      Files_Found : Cached_File_Vectors.Vector;
      Total       : Long_Long_Integer := 0;
      Search      : Ada.Directories.Search_Type;
      Item        : Ada.Directories.Directory_Entry_Type;
      Started     : Boolean := False;
      Count       : Natural := 0;
      Overflowed  : Boolean := False;
   begin
      --  A cache path may have been replaced with a directory symlink since it
      --  was configured.  Pruning is destructive, so never follow that link
      --  and evict ordinary files from an unrelated target directory.
      if Hostkit.Fs.Is_Link (Cache_Directory)
        or else not Files.Fs.Directory_Exists (Cache_Directory)
      then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search, Cache_Directory, "*",
         Filter => [Ada.Directories.Ordinary_File => True, others => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);

         if not Is_Thumbnail_Name (Ada.Directories.Simple_Name (Item)) then
            goto Continue;
         elsif Count = Max_Cache_Prune_Entries then
            Ada.Directories.End_Search (Search);
            Started := False;
            return;
         end if;
         Count := Count + 1;

         begin
            declare
               Full : constant String := Ada.Directories.Full_Name (Item);
               Size : constant Long_Long_Integer :=
                 Long_Long_Integer (Ada.Directories.Size (Item));
            begin
               if Size < 0 or else Total > Long_Long_Integer'Last - Size then
                  Overflowed := True;
               else
                  Files_Found.Append
                    (Cached_File'
                       (Path     => To_Unbounded_String (Full),
                        Identity => To_Unbounded_String
                          (Files.File_Identities.Token (Full)),
                        Size     => Size,
                        Modified => Ada.Directories.Modification_Time (Item)));
                  Total := Total + Size;
               end if;
            end;
         exception
            --  A file that vanished mid-scan, or whose size the host will not
            --  report, simply is not counted. Pruning is housekeeping: it must
            --  never be the reason a thumbnail fails to be written.
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         end;
         <<Continue>>
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;

      if Overflowed or else Total <= Budget_Bytes then
         return;
      end if;

      Sorting.Sort (Files_Found);

      for Candidate of Files_Found loop
         exit when Total <= Budget_Bytes;

         begin
            --  The cache directory is private and owned by this app, so an
            --  identity-checked unlink is enough. The full recoverable-delete
            --  protocol cost a stage directory, sidecars and about eight fsyncs
            --  per evicted thumbnail, all on the directory-listing path.
            if Length (Candidate.Identity) > 0
              and then not Hostkit.Fs.Is_Link (To_String (Candidate.Path))
              and then Files.File_Identities.Token (To_String (Candidate.Path)) =
                To_String (Candidate.Identity)
            then
               Ada.Directories.Delete_File (To_String (Candidate.Path));
               Total := Total - Candidate.Size;
            end if;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
         end;
      end loop;
   exception
      when others =>
         if Started then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when Swallowed : others =>
                  Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
            end;
         end if;
         null;
   end Prune_Thumbnail_Cache;

   --  Once per run, at the default budget. See the note above for why not per
   --  write.
   procedure Prune_Cache_Once (Cache_Directory : String) is
      Prune : Boolean;
   begin
      Cache_Prune_Registry.Claim (Cache_Directory, Prune);
      if not Prune then
         return;
      end if;
      Prune_Thumbnail_Cache (Cache_Directory, Cache_Byte_Budget);
   end Prune_Cache_Once;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is
      Raw_Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
      Xdg_Cache : constant String :=
        (if GNAT.OS_Lib.Is_Absolute_Path (Raw_Xdg_Cache) then Raw_Xdg_Cache
         else "");

      function In_Cache_Root (Root : String) return String is
        (Join_Path (Join_Path (Root, "files"), "thumbnails"));

      --  Where this host keeps a per-user cache is Hostkit's question --
      --  LOCALAPPDATA rather than the roaming APPDATA, ~/Library/Caches rather
      --  than Application Support, $XDG_CACHE_HOME or ~/.cache -- and it used to
      --  be spelled out here.
      --
      --  XDG_CACHE_HOME is checked first, before asking, because honouring it on
      --  every host is this application's policy rather than a host fact: macOS
      --  and Windows do not read it, and Hostkit says what the host does. A user
      --  who exported it meant it.
      function Host_Cache_Root return String is
      begin
         if Xdg_Cache /= "" then
            return Xdg_Cache;
         end if;

         declare
            Root : constant String := Hostkit.Fs.Cache_Directory;
         begin
            return
              (if GNAT.OS_Lib.Is_Absolute_Path (Root) then Root else "");
         end;
      end Host_Cache_Root;

      Cache_Root : constant String := Host_Cache_Root;
   begin
      if Cache_Root /= "" then
         return In_Cache_Root (Cache_Root);
      end if;

      --  Nothing to go on. Writing the cache into the directory being browsed
      --  is the last resort it has always been -- it is somewhere writable and
      --  it is where the images are -- but it leaves a hidden folder behind in
      --  the user's own data, so it is reached only when the host will not say
      --  where its cache belongs.
      return Join_Path (Fallback_Directory, ".files-thumbnails");
   end Default_Thumbnail_Cache_Directory;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is
   begin
      return
        Join_Path
          (Cache_Directory,
           "thumb_"
           & Sanitized_Thumbnail_Extension (Source_Path)
           & "_"
           & Image_No_Space (Size)
           & "_"
           & Thumbnail_Cache_Key (Source_Path)
           & ".ppm");
   end Thumbnail_Path_For;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is
      Extension : constant String := Files.File_Types.Extension_Of (Name);
   begin
      if Kind = Files.Types.Directory_Item
        or else Kind = Files.Types.Symlink_Item
      then
         return False;
      end if;

      return Starts_With (Files.Types.To_Lower (Filetype), "image/")
        or else Files.Types.To_Lower (Icon_Id) = "image"
        or else Extension = "png"
        or else Extension = "jpg"
        or else Extension = "jpeg"
        or else Extension = "gif"
        or else Extension = "bmp"
        or else Extension = "webp"
        or else Extension = "tif"
        or else Extension = "tiff"
        or else Extension = "ppm";
   end Is_Image_Item;

   function Read_Bounded_Regular_File
     (Path : String; Max_Bytes : Natural;
      Success, Complete : out Boolean) return String
   is
      use type GNAT.OS_Lib.File_Descriptor;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Result     : Ada.Strings.Unbounded.Unbounded_String;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Bytes_Read : Integer;
      Total      : Natural := 0;
   begin
      Success := False;
      Complete := False;

      Descriptor := Files.Fs.Open_Regular_Read (Path);
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return "";
      end if;

      while Total < Max_Bytes loop
         Bytes_Read := GNAT.OS_Lib.Read
           (Descriptor,
            Buffer'Address,
            Integer'Min (Integer (Buffer'Length), Max_Bytes - Total));
         if Bytes_Read < 0 then
            raise Ada.Directories.Use_Error;
         end if;
         if Bytes_Read = 0 then
            Complete := True;
            exit;
         end if;
         for Index in Buffer'First
           .. Buffer'First + Ada.Streams.Stream_Element_Offset (Bytes_Read) - 1
         loop
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Natural (Buffer (Index))));
            Total := Total + 1;
         end loop;
      end loop;

      if not Complete then
         --  Reaching the cap is not evidence that the complete file was read.
         --  Probe one byte so strict parsers cannot accept a truncated prefix
         --  after a file grows or is replaced between the size check and open.
         Bytes_Read := GNAT.OS_Lib.Read (Descriptor, Buffer'Address, 1);
         if Bytes_Read < 0 then
            raise Ada.Directories.Use_Error;
         end if;
         Complete := Bytes_Read = 0;
      end if;

      GNAT.OS_Lib.Close (Descriptor);
      Descriptor := GNAT.OS_Lib.Invalid_FD;
      Success := True;
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         Complete := False;
         return Ada.Strings.Unbounded.To_String (Result);
   end Read_Bounded_Regular_File;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      Success : Boolean;
   begin
      return Read_Preview_Text (Path, Max_Bytes, Success);
   end Read_Preview_Text;

   function Read_Preview_Text
     (Path : String; Max_Bytes : Natural; Success : out Boolean) return String
   is
      Complete : Boolean;
      Result : constant String := Read_Bounded_Regular_File
        (Path, Max_Bytes, Success, Complete);

      procedure Ignore_Completion (Value : Boolean) is
         pragma Unreferenced (Value);
      begin
         null;
      end Ignore_Completion;
   begin
      --  A preview deliberately accepts a leading prefix; strict decoders call
      --  Read_Bounded_Regular_File directly and require Complete.
      Ignore_Completion (Complete);
      return Result;
   end Read_Preview_Text;

   function Image_Bytes_Extent
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
   is
      use type Ada.Streams.Stream_Element;
      use type Ada.Streams.Stream_Element_Offset;

      --  PNG: an 8-byte signature, then IHDR's length and type, then width and
      --  height as big-endian 32-bit values at fixed offsets 16 and 20.
      Signature : constant Ada.Streams.Stream_Element_Array (0 .. 7) :=
        [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];

      function U32_At (Offset : Ada.Streams.Stream_Element_Offset) return Natural is
        (Natural (Data (Data'First + Offset)) * 16#100_0000#
         + Natural (Data (Data'First + Offset + 1)) * 16#1_0000#
         + Natural (Data (Data'First + Offset + 2)) * 16#100#
         + Natural (Data (Data'First + Offset + 3)));
   begin
      Width := 0;
      Height := 0;

      if Data'Length < 24 then
         return False;
      end if;

      for Index in Signature'Range loop
         if Data (Data'First + Index) /= Signature (Index) then
            return False;
         end if;
      end loop;

      declare
         W : constant Natural := U32_At (16);
         H : constant Natural := U32_At (20);
      begin
         --  A declared dimension is not a promise. Refuse anything that could not
         --  be an image before a caller allocates four bytes per pixel for it.
         if W = 0
           or else H = 0
           or else W > 16_384
           or else H > 16_384
           or else W > Max_Source_Pixels / H
         then
            return False;
         end if;

         Width := W;
         Height := H;
         return True;
      end;
   exception
      when others =>
         Width := 0;
         Height := 0;
         return False;
   end Image_Bytes_Extent;

   function Decode_Image_Bytes
     (Data : Ada.Streams.Stream_Element_Array)
      return Decoded_Image
   is
      type Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Pixel_Array);
      package Pixel_Pointers is new System.Address_To_Access_Conversions (Pixel_Array);
      use type Pixel_Pointers.Object_Pointer;

      Result : Decoded_Image;
      Loader : System.Address := System.Null_Address;
      Declared_Width, Declared_Height : Natural := 0;

      procedure Release_Loader is
      begin
         if Loader /= System.Null_Address then
            G_Object_Unref (Loader);
            Loader := System.Null_Address;
         end if;
      end Release_Loader;
   begin
      --  gdk-pixbuf allocates while consuming the stream. Validate the PNG's
      --  declared extent first so a compressed image cannot force an
      --  unbounded allocation before the post-decode checks run.
      if not Image_Bytes_Extent (Data, Declared_Width, Declared_Height) then
         return Result;
      end if;

      Loader := Loader_New;

      if Loader = System.Null_Address then
         return Result;
      end if;

      if Loader_Write
           (Loader, Data (Data'First)'Address,
            Interfaces.C.size_t (Data'Length), System.Null_Address) = 0
      then
         --  Close before giving up: the loader owns a partial image otherwise.
         declare
            Ignored : constant Interfaces.C.int := Loader_Close (Loader, System.Null_Address);
            pragma Unreferenced (Ignored);
         begin
            Release_Loader;
            return Result;
         end;
      end if;

      declare
         Closed : constant Interfaces.C.int := Loader_Close (Loader, System.Null_Address);

         Pixbuf : constant System.Address := Loader_Get_Pixbuf (Loader);
      begin
         if Closed = 0 or else Pixbuf = System.Null_Address then
            Release_Loader;
            return Result;
         end if;

         declare
            Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
            Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
            Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
            Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
            Address   : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
            Raw       : constant Pixel_Pointers.Object_Pointer :=
              Pixel_Pointers.To_Pointer (Address);
         begin
            if Width /= Declared_Width
              or else Height /= Declared_Height
              or else Channels not in 3 .. 4
              or else Rowstride < Width * Channels
              or else Rowstride > Pixel_Array'Length / Height
              or else Address = System.Null_Address
              or else Raw = null
            then
               Release_Loader;
               return Result;
            end if;

            Result.Width := Width;
            Result.Height := Height;
            Result.Pixels.Reserve_Capacity
              (Ada.Containers.Count_Type (Width * Height * 4));

            for Row in 0 .. Height - 1 loop
               for Column in 0 .. Width - 1 loop
                  declare
                     At_Source : constant Natural := Row * Rowstride + Column * Channels;
                  begin
                     Result.Pixels.Append (Raw.all (At_Source));
                     Result.Pixels.Append (Raw.all (At_Source + 1));
                     Result.Pixels.Append (Raw.all (At_Source + 2));

                     --  Three channels means no alpha in the source; an emoji
                     --  without alpha is opaque, not invisible.
                     Result.Pixels.Append
                       (if Channels >= 4 then Raw.all (At_Source + 3) else 255);
                  end;
               end loop;
            end loop;

            Result.Available := True;
         end;

         Release_Loader;
      end;

      return Result;
   exception
      when others =>
         Release_Loader;

         return (Available => False, Width => 0, Height => 0,
                 Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Decode_Image_Bytes;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is
      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);
      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      use type GNAT.OS_Lib.File_Descriptor;
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Loader     : System.Address := System.Null_Address;
      Loader_Was_Closed : Boolean := False;
      Signal_Name : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.Null_Ptr;
      Requested_Size : aliased C_Int := C_Int (Max_Size);
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
      Bytes_Read : Integer;
      Total      : Natural := 0;
      Result     : Decoded_Image;

      procedure Clean is
         Ignored : Interfaces.C.int;
         pragma Unreferenced (Ignored);
      begin
         Safe_Free (Signal_Name);
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
            Descriptor := GNAT.OS_Lib.Invalid_FD;
         end if;
         if Loader /= System.Null_Address then
            if not Loader_Was_Closed then
               Ignored := Loader_Close (Loader, System.Null_Address);
            end if;
            G_Object_Unref (Loader);
            Loader := System.Null_Address;
         end if;
      end Clean;
   begin
      if Max_Size > Max_Thumbnail_Dimension then
         return Result;
      end if;

      Descriptor := Files.Fs.Open_Regular_Read (Path);
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return Result;
      end if;
      Loader := Loader_New;
      if Loader = System.Null_Address then
         Clean;
         return Result;
      end if;
      Signal_Name := Interfaces.C.Strings.New_String ("size-prepared");
      if Signal_Connect_Data
        (Loader, Signal_Name, Loader_Size_Prepared'Address,
         Requested_Size'Address, System.Null_Address, 0) = 0
      then
         Clean;
         return Result;
      end if;
      Safe_Free (Signal_Name);

      loop
         Bytes_Read := GNAT.OS_Lib.Read
           (Descriptor, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0
           or else Bytes_Read > Integer (Max_Decode_Source_Bytes - Total)
         then
            Clean;
            return Result;
         end if;
         exit when Bytes_Read = 0;
         Total := Total + Bytes_Read;
         if Loader_Write
           (Loader, Buffer (Buffer'First)'Address,
            Interfaces.C.size_t (Bytes_Read), System.Null_Address) = 0
         then
            Clean;
            return Result;
         end if;
      end loop;
      GNAT.OS_Lib.Close (Descriptor);
      Descriptor := GNAT.OS_Lib.Invalid_FD;

      if Loader_Close (Loader, System.Null_Address) = 0 then
         Loader_Was_Closed := True;
         Clean;
         return Result;
      end if;
      Loader_Was_Closed := True;

      declare
         Pixbuf    : constant System.Address := Loader_Get_Pixbuf (Loader);
      begin
         if Pixbuf = System.Null_Address then
            Clean;
            return Result;
         end if;
         declare
            Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
            Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
            Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
            Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
            Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
            Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
              Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
         begin
            if Width = 0
              or else Height = 0
              or else Width > Max_Size
              or else Height > Max_Size
              or else Channels not in 3 .. 4
              or else Rowstride < Width * Channels
              or else Rowstride > Gdk_Pixel_Array'Length / Height
              or else Pixels_Address = System.Null_Address
              or else Raw = null
            then
               Clean;
               return Result;
            end if;

            --  Copy row-major RGBA (alpha from the source or opaque when absent),
            --  matching the byte layout the icon-atlas thumbnail rasterizer reads.
            for Row in 0 .. Height - 1 loop
               for Column in 0 .. Width - 1 loop
                  declare
                     Offset : constant Natural := Row * Rowstride + Column * Channels;
                  begin
                     Result.Pixels.Append (Raw.all (Offset));
                     Result.Pixels.Append (Raw.all (Offset + 1));
                     Result.Pixels.Append (Raw.all (Offset + 2));
                     Result.Pixels.Append (if Channels = 4 then Raw.all (Offset + 3) else 255);
                  end;
               end loop;
            end loop;

            Clean;
            Result.Available := True;
            Result.Width := Width;
            Result.Height := Height;
            return Result;
         end;
      end;
   exception
      when others =>
         Clean;
         return (Available => False, Width => 0, Height => 0,
                 Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Decode_Image_To_Pixels;

   function Clamp_Channel (Value : Natural) return Natural is
   begin
      return Value mod 256;
   end Clamp_Channel;

   function File_Size_Signal (Source_Path : String) return Natural is
   begin
      return Natural (Long_Long_Integer'Min (Long_Long_Integer (Ada.Directories.Size (Source_Path)), 65_535));
   exception
      when others =>
         return 0;
   end File_Size_Signal;

   --  Cap the input given to the pure-Ada PNG/PPM decoders, which read the
   --  whole file into memory before validating its magic bytes. A valid
   --  image within the 2048x2048 decode cap is at most a few MB, so 32 MiB is
   --  generous; a larger (or unreadable-size) file skips the slurping fast
   --  path and falls through to the streaming gdk-pixbuf loader, so a huge
   --  non-image named *.png can no longer be read into RAM on a directory
   --  browse (a memory/CPU denial of service).
   Max_Fast_Decode_Source_Bytes : constant Natural := 33_554_432;

   function Source_Fits_Fast_Decode (Source_Path : String) return Boolean is
   begin
      return Long_Long_Integer (Ada.Directories.Size (Source_Path))
               <= Long_Long_Integer (Max_Fast_Decode_Source_Bytes);
   exception
      when others =>
         return False;
   end Source_Fits_Fast_Decode;

   type Rgba_Pixel is record
      Red   : Natural := 0;
      Green : Natural := 0;
      Blue  : Natural := 0;
      Alpha : Natural := 255;
   end record;

   package Pixel_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Rgba_Pixel);

   package Thumbnail_Byte_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Ada.Streams.Stream_Element);

   type Stream_Element_Array_Access is
     access Ada.Streams.Stream_Element_Array;
   procedure Free_Stream_Element_Array is new Ada.Unchecked_Deallocation
     (Object => Ada.Streams.Stream_Element_Array,
      Name   => Stream_Element_Array_Access);

   type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
   pragma Convention (C, Gdk_Pixel_Array);

   package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
   use type Gdk_Pixel_Pointers.Object_Pointer;

   function Byte_At
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural is
   begin
      if Index >= Natural (Data.Length) then
         return 0;
      end if;

      return Natural (Data.Element (Index));
   end Byte_At;

   function U32_BE_From
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural
   is
      use type Interfaces.Unsigned_32;
      Value : constant Interfaces.Unsigned_32 :=
        Interfaces.Unsigned_32 (Byte_At (Data, Index)) * 16#1000000#
        + Interfaces.Unsigned_32 (Byte_At (Data, Index + 1)) * 16#10000#
        + Interfaces.Unsigned_32 (Byte_At (Data, Index + 2)) * 16#100#
        + Interfaces.Unsigned_32 (Byte_At (Data, Index + 3));
   begin
      --  Compute in Unsigned_32 (modular, no overflow) and clamp: a crafted
      --  PNG length/dimension with the high bit set exceeds Natural'Last, and
      --  the old Natural arithmetic overflowed into a Constraint_Error.
      --  Callers reject the resulting too-large dimension anyway.
      return Natural (Interfaces.Unsigned_32'Min (Value, Interfaces.Unsigned_32 (Natural'Last)));
   end U32_BE_From;

   function Bytes_To_Stream_Array
     (Data : Thumbnail_Byte_Vectors.Vector)
      return Stream_Element_Array_Access
   is
      Result : Stream_Element_Array_Access :=
        new Ada.Streams.Stream_Element_Array
          (0 .. Ada.Streams.Stream_Element_Offset (Data.Length) - 1);
   begin
      for Index in 0 .. Natural (Data.Length) - 1 loop
         Result (Ada.Streams.Stream_Element_Offset (Index)) :=
           Data.Element (Index);
      end loop;

      return Result;
   exception
      when others =>
         Free_Stream_Element_Array (Result);
         raise;
   end Bytes_To_Stream_Array;

   --  Binary P6, not the ASCII P3 this used to write.
   --
   --  Identical pixels either way, but a 64x64 thumbnail is 12 KB here and
   --  was 43 KB as text, and the loader on the directory-listing path had to
   --  turn some twelve thousand ASCII numbers per thumbnail into as many
   --  strings to read one back.
   --
   --  Stream_IO rather than Text_IO, and not only for the line endings:
   --  Alire's switches carry -gnatW8, so Text_IO would try to encode every
   --  pixel byte above 127 as UTF-8 on the way out and corrupt the image.
   --  Load_Cached_Thumbnail reads both formats, so caches written before
   --  this keep working rather than being silently discarded.
   procedure Write_Pixels_As_Ppm
     (Target_Path   : String;
      Size          : Positive;
      Pixels        : Pixel_Vectors.Vector;
      Source_Width  : Natural;
      Source_Height : Natural)
   is
      use Ada.Streams;

      Output : Stream_IO.File_Type;
      Row_Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size) * 3);

      procedure Put_Header (Text : String) is
         Buffer : Stream_Element_Array (1 .. Text'Length);
      begin
         for Index in Text'Range loop
            Buffer (Stream_Element_Offset (Index - Text'First + 1)) :=
              Stream_Element (Character'Pos (Text (Index)));
         end loop;

         Stream_IO.Write (Output, Buffer);
      end Put_Header;

      function Against_White
        (Channel, Alpha : Natural) return Stream_Element is
        (Stream_Element
           ((Channel * Alpha + 255 * (255 - Alpha) + 127) / 255));
   begin
      Stream_IO.Create (Output, Stream_IO.Out_File, Target_Path);
      Put_Header
        ("P6" & ASCII.LF
         & Image_No_Space (Size) & " " & Image_No_Space (Size) & ASCII.LF
         & "255" & ASCII.LF);

      for Row in 0 .. Size - 1 loop
         for Column in 0 .. Size - 1 loop
            declare
               Source_Row    : constant Natural := Row * Source_Height / Size;
               Source_Column : constant Natural := Column * Source_Width / Size;
               Source_Index  : constant Natural := Source_Row * Source_Width + Source_Column;
               Pixel         : constant Rgba_Pixel := Pixels.Element (Source_Index);
               At_Byte       : constant Stream_Element_Offset :=
                 Stream_Element_Offset (Column) * 3 + 1;
            begin
               --  PPM has no alpha channel. Composite rather than exposing
               --  arbitrary RGB values hidden beneath transparent pixels.
               Row_Bytes (At_Byte)     := Against_White (Pixel.Red, Pixel.Alpha);
               Row_Bytes (At_Byte + 1) := Against_White (Pixel.Green, Pixel.Alpha);
               Row_Bytes (At_Byte + 2) := Against_White (Pixel.Blue, Pixel.Alpha);
            end;
         end loop;

         Stream_IO.Write (Output, Row_Bytes);
      end loop;

      Stream_IO.Close (Output);
   exception
      when others =>
         if Stream_IO.Is_Open (Output) then
            Stream_IO.Close (Output);
         end if;
         raise;
   end Write_Pixels_As_Ppm;

   function Try_Write_Decoded_P3_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   function Try_Write_Decoded_Png_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   function Try_Write_Gdk_Pixbuf_Thumbnail
     (Source_Path : String;
      Size        : Positive;
      Target_Path : String)
      return Boolean
   is separate;

   Checksum  : Natural := 0;
   Size_Bias : Natural := 0;
   Target    : Unbounded_String;

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
         Stream_IO.Create (File, Stream_IO.Out_File, To_String (Temp));
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

end Thumbnails;
