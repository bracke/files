with Ada.Containers;
with GNAT.OS_Lib;
with Files.Diagnostics;
with Files.Fs_Primitives;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with System.Address_To_Access_Conversions;

package body Files.Images is

   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type System.Address;
   use type Ada.Streams.Stream_Element_Offset;

   subtype C_Int is Interfaces.C.int;

   Max_Decode_Source_Bytes : constant Natural := 128 * 1024 * 1024;

   function U32_BE
     (Data  : Ada.Streams.Stream_Element_Array;
      First : Ada.Streams.Stream_Element_Offset)
      return Natural
   is
      Value : constant Long_Long_Integer :=
        Long_Long_Integer (Data (First)) * 16#100_0000#
        + Long_Long_Integer (Data (First + 1)) * 16#1_0000#
        + Long_Long_Integer (Data (First + 2)) * 16#100#
        + Long_Long_Integer (Data (First + 3));
   begin
      return Natural (Long_Long_Integer'Min (Value, Long_Long_Integer (Natural'Last)));
   end U32_BE;

   function PNG_Header
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
   is
      use type Ada.Streams.Stream_Element_Array;
      --  The signature, then IHDR's length (13) and type.
      Start : constant Ada.Streams.Stream_Element_Array :=
        PNG_Magic & [0, 0, 0, 13]
        & [Character'Pos ('I'), Character'Pos ('H'), Character'Pos ('D'), Character'Pos ('R')];
   begin
      Width := 0;
      Height := 0;
      if Data'Length < 24 or else Data (Data'First .. Data'First + Start'Length - 1) /= Start then
         return False;
      end if;
      Width := U32_BE (Data, Data'First + 16);
      Height := U32_BE (Data, Data'First + 20);
      return True;
   end PNG_Header;

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

   --  The format and declared size of the image file at Filename, read from
   --  its header without decoding it; null when no loader knows the format.
   function Gdk_Pixbuf_Get_File_Info
     (Filename : Interfaces.C.Strings.chars_ptr;
      Width    : access C_Int;
      Height   : access C_Int)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_file_info";

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
   is separate;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is separate;

   --  Whether a declared extent is one a file decode accepts.
   function Within_Source_Bounds (Width, Height : Natural) return Boolean is
     (Width > 0 and then Height > 0
      and then Width <= Max_File_Source_Side and then Height <= Max_File_Source_Side
      and then Width <= Max_File_Source_Pixels / Height);

   --  gdk-pixbuf allocates the full source while consuming the stream, before
   --  the post-decode checks run: refuse a file whose header declares more
   --  than the file bounds. Head is the file's first bytes; a PNG is measured
   --  from its raw IHDR (not Image_Bytes_Extent, whose bounds are the
   --  in-memory ones). A format no loader recognizes is left to the loader.
   function Declared_Extent_Allowed
     (Path : String;
      Head : Ada.Streams.Stream_Element_Array)
      return Boolean
   is
      Width, Height : Natural;
   begin
      if PNG_Header (Head, Width, Height) then
         return Within_Source_Bounds (Width, Height);
      end if;
      declare
         Name        : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
         Info_Width  : aliased C_Int := 0;
         Info_Height : aliased C_Int := 0;
         Format      : constant System.Address :=
           Gdk_Pixbuf_Get_File_Info (Name, Info_Width'Access, Info_Height'Access);
      begin
         Safe_Free (Name);
         if Format = System.Null_Address or else Info_Width <= 0 or else Info_Height <= 0 then
            return True;
         end if;
         return Within_Source_Bounds (Natural (Info_Width), Natural (Info_Height));
      end;
   end Declared_Extent_Allowed;

   function Image_Bytes_Extent
     (Data   : Ada.Streams.Stream_Element_Array;
      Width  : out Natural;
      Height : out Natural)
      return Boolean
   is separate;

   function Decode_Image_Bytes
     (Data : Ada.Streams.Stream_Element_Array)
      return Decoded_Image
   is separate;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is separate;

end Files.Images;
