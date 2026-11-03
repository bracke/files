with Files.Environment;
with Files.Diagnostics;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with System;

with GNAT.OS_Lib;

with Zlib;

with Files.File_Types;

with Hostkit.Fs;
with Files.File_System.Support;
with Files.Images;
with Interfaces;
with Files.File_Identities;
with Files.Private_Directories;
with Ada.Characters;
with Ada.Containers.Ordered_Sets;
with Ada.Unchecked_Deallocation;
with CryptoLib.Hashes;
with GNAT.CRC32;

package body Files.File_System.Thumbnails is

   use Files.File_System.Support;
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   use type System.Address;
   use type Files.Types.Item_Kind;

   package Stream_IO renames Ada.Streams.Stream_IO;

   --  What Files.Images decodes, which bounds what is made here.
   Max_Source_Side   : constant := Files.Images.Max_Source_Side;
   Max_Source_Pixels : constant := Files.Images.Max_Source_Pixels;
   Max_Thumbnail_Dimension : constant Positive := Files.Images.Max_Decoded_Side;
   PNG_Magic : Ada.Streams.Stream_Element_Array renames Files.Images.PNG_Magic;

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

   function Thumbnail_Extension
     (Source_Path : String)
      return String
   is separate;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
   is separate;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
   is separate;

   function Thumbnail_Cache_Key
     (Source_Path : String)
      return String
   is separate;

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
   is separate;

   procedure Prune_Cache_Once (Cache_Directory : String) is separate;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is separate;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is separate;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is separate;

   function Clamp_Channel (Value : Natural) return Natural is separate;

   function File_Size_Signal (Source_Path : String) return Natural is separate;

   Max_Fast_Decode_Source_Bytes : constant Natural := 33_554_432;

   function Source_Fits_Fast_Decode (Source_Path : String) return Boolean is separate;

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

   function Byte_At
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural is separate;

   function U32_BE_From
     (Data  : Thumbnail_Byte_Vectors.Vector;
      Index : Natural)
      return Natural
   is separate;

   function Bytes_To_Stream_Array
     (Data : Thumbnail_Byte_Vectors.Vector)
      return Stream_Element_Array_Access
   is separate;

   procedure Write_Pixels_As_Ppm
     (Target_Path   : String;
      Size          : Positive;
      Pixels        : Pixel_Vectors.Vector;
      Source_Width  : Natural;
      Source_Height : Natural)
   is separate;

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

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
   is separate;

   Max_Cached_Thumbnail_Bytes  : constant Natural := 16 * 1024 * 1024;

   Max_Legacy_Thumbnail_Bytes  : constant Natural := 1 * 1024 * 1024;

   Max_Cached_Thumbnail_Pixels : constant Natural := 2_048 * 2_048;

   Max_Thumbnail_Cache_Entries : constant Natural := 100_000;

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail;

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail
   is separate;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is separate;

   function List_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is separate;

   protected Cache_Index_Memo is
      function Holds (Directory : String; Stamp : Ada.Calendar.Time) return Boolean;
      function Contains (Name : String) return Boolean;
      procedure Keep (Directory : String; Stamp : Ada.Calendar.Time; Index : Cache_Index);
   private
      Kept_Directory : Unbounded_String;
      Kept_Stamp     : Ada.Calendar.Time := Files.Types.Unknown_Time;
      Kept_Index     : Cache_Index;
      Valid          : Boolean := False;
   end Cache_Index_Memo;

   protected body Cache_Index_Memo is
      function Holds (Directory : String; Stamp : Ada.Calendar.Time) return Boolean is
      begin
         return Valid and then To_String (Kept_Directory) = Directory and then Kept_Stamp = Stamp;
      end Holds;

      function Contains (Name : String) return Boolean is
        (Valid and then Kept_Index.Names.Contains (Name));

      procedure Keep (Directory : String; Stamp : Ada.Calendar.Time; Index : Cache_Index) is
      begin
         Kept_Directory := To_Unbounded_String (Directory);
         Kept_Stamp := Stamp;
         Kept_Index := Index;
         Valid := True;
      end Keep;
   end Cache_Index_Memo;

   function Index_Thumbnail_Cache (Cache_Directory : String) return Cache_Index is separate;

   function Cache_Holds (Index : Cache_Index; Name : String) return Boolean is
     (if Index.Shared then Cache_Index_Memo.Contains (Name) else Index.Names.Contains (Name));

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String;
      Cached          : Cache_Index)
      return Cached_Thumbnail
   is separate;

end Files.File_System.Thumbnails;
