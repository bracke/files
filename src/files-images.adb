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
   is separate;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is separate;

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
