with Ada.Strings.Unbounded;

with Interfaces.C;
with Glfw.Windows.Vulkan;
with System.Address_To_Access_Conversions;

package body Files.Rendering.Vulkan is
   use Ada.Strings.Unbounded;
   use type Interfaces.C.C_float;
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Integer_32;
   use type System.Address;
   use type Files.Rendering.Text_Render_Status;
   use type Vk.Result_T;
   use type Vk.Format_T;
   use type Vk.Color_Space_KHR_T;

   Structure_Type_Swapchain_Create_Info_KHR : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_000);
   Structure_Type_Present_Info_KHR : constant Vk.Structure_Type_T :=
     Vk.Structure_Type_T (1_000_001_001);
   Suboptimal_KHR : constant Vk.Result_T := Vk.Result_T (1_000_001_003);
   Error_Out_Of_Date_KHR : constant Vk.Result_T := Vk.Result_T (-1_000_001_004);
   Image_Layout_Present_Src_KHR : constant Vk.Image_Layout_T := Vk.Image_Layout_T (1_000_001_002);
   Max_Surface_Formats : constant Positive := 32;
   Max_Batch_Vertices : constant Positive := 65_536;
   Max_Atlas_Bytes : constant Positive := 4_194_304;
   Max_Readback_Bytes : constant Positive := 33_554_432;
   Icon_Atlas_Tile_Size : constant Positive := 64;
   Icon_Atlas_Channels : constant Positive := 4;
   Max_Icon_Atlas_Tiles : constant Positive :=
     Max_Atlas_Bytes / (Icon_Atlas_Tile_Size * Icon_Atlas_Tile_Size * Icon_Atlas_Channels);
   Infinite_Timeout : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64'Last;
   Format_R8G8B8A8_Unorm : constant Vk.Format_T := Vk.Format_T (37);

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Saturating_Multiply
     (Value  : Natural;
      Factor : Natural)
      return Natural is
   begin
      if Factor = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Natural'Last;
      else
         return Value * Factor;
      end if;
   end Saturating_Multiply;

   function Scaled_Down
     (Value       : Natural;
      Numerator   : Positive;
      Denominator : Positive)
      return Natural is
   begin
      return
        Saturating_Add
          (Saturating_Multiply (Value / Denominator, Numerator),
           Saturating_Multiply (Value mod Denominator, Numerator) / Denominator);
   end Scaled_Down;

   function Bounded_Product_Divide
     (Value       : Natural;
      Factor      : Natural;
      Denominator : Positive)
      return Natural is
   begin
      if Factor = 0 or else Value = 0 then
         return 0;
      elsif Value > Natural'Last / Factor then
         return Scaled_Down (Value, Factor, Denominator);
      else
         return (Value * Factor) / Denominator;
      end if;
   end Bounded_Product_Divide;

   function Is_Toolbar_Icon
     (Icon_Id : String)
      return Boolean is
   begin
      return Icon_Id'Length >= 8
        and then Icon_Id (Icon_Id'First .. Icon_Id'First + 7) = "toolbar-";
   end Is_Toolbar_Icon;

   type Gpu_Vertex is record
      X : Interfaces.C.C_float := 0.0;
      Y : Interfaces.C.C_float := 0.0;
      U : Interfaces.C.C_float := 0.0;
      V : Interfaces.C.C_float := 0.0;
      R : Interfaces.C.C_float := 0.0;
      G : Interfaces.C.C_float := 0.0;
      B : Interfaces.C.C_float := 0.0;
      A : Interfaces.C.C_float := 1.0;
      Textured : Interfaces.C.C_float := 0.0;
      Texture : Interfaces.C.C_float := 0.0;
   end record
     with Convention => C;

   type Gpu_Vertex_Buffer_Array is array (Positive range 1 .. Max_Batch_Vertices) of aliased Gpu_Vertex
     with Convention => C;

   package Gpu_Vertex_Buffer_Conversions is new System.Address_To_Access_Conversions (Gpu_Vertex_Buffer_Array);

   type Byte_Array is array (Positive range 1 .. Max_Atlas_Bytes) of aliased Interfaces.Unsigned_8
     with Convention => C;

   package Byte_Array_Conversions is new System.Address_To_Access_Conversions (Byte_Array);

   type Readback_Byte_Array is array (Positive range 1 .. Max_Readback_Bytes) of aliased Interfaces.Unsigned_8
     with Convention => C;

   package Readback_Byte_Array_Conversions is new System.Address_To_Access_Conversions (Readback_Byte_Array);

   Fallback_Atlas_Pixel : aliased Interfaces.Unsigned_8 := 255;

   Gpu_Vertex_Size : constant Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (Gpu_Vertex'Size / 8);
   Gpu_Vertex_Buffer_Size : constant Interfaces.Unsigned_64 :=
     Interfaces.Unsigned_64 (Max_Batch_Vertices) * Gpu_Vertex_Size;

   type Shader_Code_Array is array (Positive range <>) of aliased Interfaces.Unsigned_32
     with Convention => C;

   Vertex_Shader_Code : aliased constant Shader_Code_Array :=
     [119734787, 65536, 524299, 43, 0, 131089, 1, 393227,
      1, 1280527431, 1685353262, 808793134, 0, 196622, 0, 1,
      983055, 0, 4, 1852399981, 0, 13, 18, 28,
      29, 31, 33, 36, 38, 40, 41, 196611,
      2, 450, 262149, 4, 1852399981, 0, 393221, 11,
      1348430951, 1700164197, 2019914866, 0, 393222, 11, 0, 1348430951,
      1953067887, 7237481, 458758, 11, 1, 1348430951, 1953393007, 1702521171,
      0, 458758, 11, 2, 1130327143, 1148217708, 1635021673, 6644590,
      458758, 11, 3, 1130327143, 1147956341, 1635021673, 6644590, 196613,
      13, 0, 262149, 18, 1885302377, 29551, 262149, 28,
      1601467759, 30325, 262149, 29, 1969188457, 118, 327685, 31,
      1601467759, 1869377379, 114, 327685, 33, 1667198569, 1919904879, 0,
      393221, 36, 1601467759, 1954047348, 1684370037, 0, 327685, 38,
      1952411241, 1970567269, 6579570, 458757, 40, 1601467759, 1954047348, 1600483957,
      1920298867, 25955, 458757, 41, 1952411241, 1970567269, 1935631730, 1668445551,
      101, 196679, 11, 2, 327752, 11, 0, 11,
      0, 327752, 11, 1, 11, 1, 327752, 11,
      2, 11, 3, 327752, 11, 3, 11, 4,
      262215, 18, 30, 0, 262215, 28, 30, 0,
      262215, 29, 30, 1, 262215, 31, 30, 1,
      262215, 33, 30, 2, 262215, 36, 30, 2,
      262215, 38, 30, 3, 262215, 40, 30, 3,
      262215, 41, 30, 4, 131091, 2, 196641, 3,
      2, 196630, 6, 32, 262167, 7, 6, 4,
      262165, 8, 32, 0, 262187, 8, 9, 1,
      262172, 10, 6, 9, 393246, 11, 7, 6,
      10, 10, 262176, 12, 3, 11, 262203, 12,
      13, 3, 262165, 14, 32, 1, 262187, 14,
      15, 0, 262167, 16, 6, 2, 262176, 17,
      1, 16, 262203, 17, 18, 1, 262187, 6,
      20, 0, 262187, 6, 21, 1065353216, 262176, 25,
      3, 7, 262176, 27, 3, 16, 262203, 27,
      28, 3, 262203, 17, 29, 1, 262203, 25,
      31, 3, 262176, 32, 1, 7, 262203, 32,
      33, 1, 262176, 35, 3, 6, 262203, 35,
      36, 3, 262176, 37, 1, 6, 262203, 37,
      38, 1, 262203, 35, 40, 3, 262203, 37,
      41, 1, 327734, 2, 4, 0, 3, 131320,
      5, 262205, 16, 19, 18, 327761, 6, 22,
      19, 0, 327761, 6, 23, 19, 1, 458832,
      7, 24, 22, 23, 20, 21, 327745, 25,
      26, 13, 15, 196670, 26, 24, 262205, 16,
      30, 29, 196670, 28, 30, 262205, 7, 34,
      33, 196670, 31, 34, 262205, 6, 39, 38,
      196670, 36, 39, 262205, 6, 42, 41, 196670,
      40, 42, 65789, 65592];

   Fragment_Shader_Code : aliased constant Shader_Code_Array :=
     [119734787, 65536, 524299, 74, 0, 131089, 1, 393227,
      1, 1280527431, 1685353262, 808793134, 0, 196622, 0, 1,
      655375, 4, 4, 1852399981, 0, 11, 14, 21,
      35, 72, 196624, 4, 7, 196611, 2, 450,
      262149, 4, 1852399981, 0, 262149, 9, 1869377379,
      114, 327685, 11, 1667198569, 1919904879, 0, 327685, 14,
      1952411241, 1970567269, 6579570, 458757, 21, 1952411241, 1970567269, 1935631730,
      1668445551, 101, 393221, 27, 1886216563, 1667196268, 1919904879, 0,
      327685, 31, 1852793705, 1819566431, 29537, 262149, 35, 1969188457,
      118, 262149, 54, 1752198241, 97, 327685, 55, 1954047348,
      1819566431, 29537, 327685, 72, 1601467759, 1869377379, 114, 262215,
      11, 30, 1, 262215, 14, 30, 2, 262215,
      21, 30, 3, 262215, 31, 33, 1, 262215,
      31, 34, 0, 262215, 35, 30, 0, 262215,
      55, 33, 0, 262215, 55, 34, 0, 262215,
      72, 30, 0, 131091, 2, 196641, 3, 2,
      196630, 6, 32, 262167, 7, 6, 4, 262176,
      8, 7, 7, 262176, 10, 1, 7, 262203,
      10, 11, 1, 262176, 13, 1, 6, 262203,
      13, 14, 1, 262187, 6, 16, 1056964608, 131092,
      17, 262203, 13, 21, 1, 262187, 6, 23,
      1069547520, 589849, 28, 6, 1, 0, 0, 0,
      1, 0, 196635, 29, 28, 262176, 30, 0,
      29, 262203, 30, 31, 0, 262167, 33, 6,
      2, 262176, 34, 1, 33, 262203, 34, 35,
      1, 262167, 38, 6, 3, 262165, 41,
      32, 0, 262187, 41, 42, 3, 262176, 43,
      7, 6, 262203, 30, 55, 0, 262187, 41,
      59, 0, 262176, 71, 3, 7, 262203, 71, 72,
      3, 327734, 2, 4, 0, 3, 131320, 5,
      262203, 8, 9, 7, 262203, 8, 27, 7,
      262203, 43, 54, 7, 262205, 7, 12, 11,
      196670, 9, 12, 262205, 6, 15, 14, 327866,
      17, 18, 15, 16, 196855, 20, 0, 262394,
      18, 19, 20, 131320, 19, 262205, 6, 22,
      21, 327866, 17, 24, 22, 23, 196855, 26,
      0, 262394, 24, 25, 53, 131320, 25, 262205,
      29, 32, 31, 262205, 33, 36, 35, 327767,
      7, 37, 32, 36, 196670, 27, 37, 262205,
      7, 39, 27, 524367, 38, 40, 39, 39,
      0, 1, 2, 327745, 43, 44, 27, 42,
      262205, 6, 45, 44, 327745, 13, 46, 11,
      42, 262205, 6, 47, 46, 327813, 6, 48,
      45, 47, 327761, 6, 49, 40, 0, 327761,
      6, 50, 40, 1, 327761, 6, 51, 40,
      2, 458832, 7, 52, 49, 50, 51, 48,
      196670, 9, 52, 131321, 26, 131320, 53, 262205,
      29, 56, 55, 262205, 33, 57, 35, 327767,
      7, 58, 56, 57, 327761, 6, 60, 58,
      0, 327745, 13, 61, 11, 42, 262205, 6,
      62, 61, 327813, 6, 63, 60, 62, 196670,
      54, 63, 262205, 7, 64, 11, 524367, 38,
      65, 64, 64, 0, 1, 2, 262205, 6,
      66, 54, 327761, 6, 67, 65, 0, 327761,
      6, 68, 65, 1, 327761, 6, 69, 65,
      2, 458832, 7, 70, 67, 68, 69, 66,
      196670, 9, 70, 131321, 26, 131320, 26, 131321,
      20, 131320, 20, 262205, 7, 73, 9, 196670,
      72, 73, 65789, 65592];

   type Surface_Format_Array is array (Positive range <>) of aliased Vk.Surface_Format_KHR_T
     with Convention => C;

   type Swapchain_Array is array (Positive range <>) of aliased Vk.Swapchain_KHR_T
     with Convention => C;

   type Image_Index_Array is array (Positive range <>) of aliased Interfaces.Unsigned_32
     with Convention => C;

   type Semaphore_Array is array (Positive range <>) of aliased Vk.Semaphore_T
     with Convention => C;

   type Queue_Family_Array is array (Positive range <>) of aliased Vk.Queue_Family_Properties_T
     with Convention => C;

   type Address_Array is array (Positive range <>) of aliased System.Address
     with Convention => C;

   type Image_Array is array (Positive range <>) of aliased Vk.Image_T
     with Convention => C;

   type Command_Buffer_Array_C is array (Positive range <>) of aliased Vk.Command_Buffer_T
     with Convention => C;

   type Fence_Array_C is array (Positive range <>) of aliased Vk.Fence_T
     with Convention => C;

   type Buffer_Array_C is array (Positive range <>) of aliased Vk.Buffer_T
     with Convention => C;

   type Buffer_Offset_Array_C is array (Positive range <>) of aliased Interfaces.Unsigned_64
     with Convention => C;

   type Shader_Stage_Array is array (Positive range <>) of aliased Vk.Pipeline_Shader_Stage_Create_Info_T
     with Convention => C;

   type Vertex_Binding_Array is array (Positive range <>) of aliased Vk.Vertex_Input_Binding_Description_T
     with Convention => C;

   type Vertex_Attribute_Array is array (Positive range <>) of aliased Vk.Vertex_Input_Attribute_Description_T
     with Convention => C;

   type Descriptor_Set_Array_C is array (Positive range <>) of aliased Vk.Descriptor_Set_T
     with Convention => C;

   type Descriptor_Set_Layout_Array_C is array (Positive range <>) of aliased Vk.Descriptor_Set_Layout_T
     with Convention => C;

   type Descriptor_Set_Layout_Binding_Array is array
     (Positive range <>) of aliased Vk.Descriptor_Set_Layout_Binding_T
     with Convention => C;

   type Descriptor_Pool_Size_Array is array (Positive range <>) of aliased Vk.Descriptor_Pool_Size_T
     with Convention => C;

   function Clamp
     (Value : Interfaces.Unsigned_32;
      Low   : Interfaces.Unsigned_32;
      High  : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32;

   function Choose_Graphics_Queue_Family
     (Physical : Vk.Physical_Device_T)
      return Interfaces.Unsigned_32;

   procedure Destroy_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer);

   function Create_Render_Targets
     (Renderer : in out Vulkan_Renderer;
      Format   : Vk.Format_T)
      return Boolean;

   function Create_Graphics_Pipeline
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Create_Descriptor_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Create_Command_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean;

   function Ensure_Vertex_Buffer
     (Renderer : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean;

   function Upload_Vertices
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean;

   function Upload_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean;

   function Upload_Icon_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean;

   function Ensure_Readback_Buffer
     (Renderer : in out Vulkan_Renderer;
      Byte_Count : Natural)
      return Boolean;

   procedure Capture_Completed_Readback
     (Renderer : in out Vulkan_Renderer);

   function Record_Command_Buffers
     (Renderer     : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean;

   function Create_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status;

   function Color_To_Vertex
     (Color : Files.Rendering.Render_Color)
      return Gpu_Vertex;

   function Host_Visible_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean;

   function Any_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean;

   function Clamp
     (Value : Interfaces.Unsigned_32;
      Low   : Interfaces.Unsigned_32;
      High  : Interfaces.Unsigned_32)
      return Interfaces.Unsigned_32 is
   begin
      if Value < Low then
         return Low;
      elsif High /= 0 and then Value > High then
         return High;
      else
         return Value;
      end if;
   end Clamp;

   function Choose_Graphics_Queue_Family
     (Physical : Vk.Physical_Device_T)
      return Interfaces.Unsigned_32
   is
      Count : aliased Interfaces.Unsigned_32 := 0;
      Properties : Queue_Family_Array (1 .. 32);
   begin
      Vk.Get_Physical_Device_Queue_Family_Properties
        (physical_Device               => Physical,
         p_Queue_Family_Property_Count => Count'Address,
         p_Queue_Family_Properties     => System.Null_Address);

      if Count = 0 then
         return 0;
      end if;

      if Count > Properties'Length then
         Count := Properties'Length;
      end if;

      Vk.Get_Physical_Device_Queue_Family_Properties
        (physical_Device               => Physical,
         p_Queue_Family_Property_Count => Count'Address,
         p_Queue_Family_Properties     => Properties (Properties'First)'Address);

      for Index in 1 .. Natural (Count) loop
         if (Properties (Index).queue_Flags and Vk.QUEUE_GRAPHICS_BIT) /= 0
           and then Properties (Index).queue_Count > 0
         then
            return Interfaces.Unsigned_32 (Index - 1);
         end if;
      end loop;

      return 0;
   end Choose_Graphics_Queue_Family;

   function Color_To_Vertex
     (Color : Files.Rendering.Render_Color)
      return Gpu_Vertex
   is
      function Make
        (R : Interfaces.C.C_float;
         G : Interfaces.C.C_float;
         B : Interfaces.C.C_float;
         A : Interfaces.C.C_float := 1.0)
         return Gpu_Vertex is
      begin
         return
           (X        => 0.0,
            Y        => 0.0,
            U        => 0.0,
            V        => 0.0,
            R        => R,
            G        => G,
            B        => B,
            A        => A,
            Textured => 0.0,
            Texture  => 0.0);
      end Make;
   begin
      case Color is
         when Files.Rendering.Canvas_Color =>
            return Make (0.08, 0.09, 0.10);
         when Files.Rendering.Toolbar_Color =>
            return Make (0.14, 0.15, 0.16);
         when Files.Rendering.Bottom_Bar_Color =>
            return Make (0.12, 0.13, 0.14);
         when Files.Rendering.Main_Color =>
            return Make (0.10, 0.11, 0.12);
         when Files.Rendering.Detail_Alternate_Color =>
            return Make (0.12, 0.13, 0.14);
         when Files.Rendering.Pane_Color =>
            return Make (0.16, 0.17, 0.18);
         when Files.Rendering.Input_Color =>
            return Make (0.18, 0.19, 0.20);
         when Files.Rendering.Input_Error_Color =>
            return Make (0.44, 0.12, 0.14);
         when Files.Rendering.Selection_Color =>
            return Make (0.21, 0.38, 0.62);
         when Files.Rendering.Hover_Color =>
            return Make (0.20, 0.22, 0.24);
         when Files.Rendering.Pressed_Color =>
            return Make (0.17, 0.24, 0.34);
         when Files.Rendering.Border_Color =>
            return Make (0.28, 0.29, 0.30);
         when Files.Rendering.Text_Color =>
            return Make (0.86, 0.87, 0.88);
         when Files.Rendering.Muted_Text_Color =>
            return Make (0.58, 0.60, 0.62);
         when Files.Rendering.Error_Text_Color =>
            return Make (0.94, 0.30, 0.27);
         when Files.Rendering.Disabled_Text_Color =>
            return Make (0.40, 0.41, 0.42);
         when Files.Rendering.Icon_Directory_Color =>
            return Make (0.32, 0.50, 0.82);
         when Files.Rendering.Icon_File_Color =>
            return Make (0.70, 0.72, 0.74);
         when Files.Rendering.Icon_Executable_Color =>
            return Make (0.38, 0.68, 0.42);
         when Files.Rendering.Icon_Unknown_Color =>
            return Make (0.55, 0.55, 0.57);
         when Files.Rendering.Overlay_Color =>
            return Make (0.04, 0.05, 0.06, 0.86);
      end case;
   end Color_To_Vertex;

   function Host_Visible_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean
   is
      Properties : aliased Vk.Physical_Device_Memory_Properties_T;
      Required   : constant Interfaces.Unsigned_32 :=
        Vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT or Vk.MEMORY_PROPERTY_HOST_COHERENT_BIT;
   begin
      Vk.Get_Physical_Device_Memory_Properties
        (physical_Device     => Renderer.Physical_Device,
         p_Memory_Properties => Properties'Address);

      for Index in 0 .. Natural (Properties.memory_Type_Count) - 1 loop
         if (Memory_Type_Bits and Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Index)) /= 0
           and then (Properties.memory_Types (Index).property_Flags and Required) = Required
         then
            Memory_Type := Interfaces.Unsigned_32 (Index);
            return True;
         end if;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Host_Visible_Memory_Type;

   function Any_Memory_Type
     (Renderer         : Vulkan_Renderer;
      Memory_Type_Bits : Interfaces.Unsigned_32;
      Memory_Type      : out Interfaces.Unsigned_32)
      return Boolean
   is
      Properties : aliased Vk.Physical_Device_Memory_Properties_T;
   begin
      Vk.Get_Physical_Device_Memory_Properties
        (physical_Device     => Renderer.Physical_Device,
         p_Memory_Properties => Properties'Address);

      for Index in 0 .. Natural (Properties.memory_Type_Count) - 1 loop
         if (Memory_Type_Bits and Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Index)) /= 0 then
            Memory_Type := Interfaces.Unsigned_32 (Index);
            return True;
         end if;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Any_Memory_Type;

   procedure Destroy_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer) is
   begin
      if Renderer.Device_Live then
         if Renderer.Command_Buffer_Count > 0 and then Renderer.Command_Pool /= System.Null_Address then
            Vk.Free_Command_Buffers
              (device               => Renderer.Device,
               command_Pool         => Renderer.Command_Pool,
               command_Buffer_Count => Renderer.Command_Buffer_Count,
               p_Command_Buffers    => Renderer.Command_Buffers (Renderer.Command_Buffers'First)'Address);
         end if;

         if Renderer.Command_Pool /= System.Null_Address then
            Vk.Destroy_Command_Pool
              (device        => Renderer.Device,
               command_Pool  => Renderer.Command_Pool,
               p_Allocator   => System.Null_Address);
            Renderer.Command_Pool := System.Null_Address;
         end if;

         if Renderer.Vertex_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer
              (device      => Renderer.Device,
               buffer      => Renderer.Vertex_Buffer,
               p_Allocator => System.Null_Address);
            Renderer.Vertex_Buffer := System.Null_Address;
         end if;

         if Renderer.Vertex_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Vertex_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Vertex_Memory := System.Null_Address;
         end if;

         if Renderer.Atlas_Staging_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer
              (device      => Renderer.Device,
               buffer      => Renderer.Atlas_Staging_Buffer,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_Staging_Buffer := System.Null_Address;
         end if;

         if Renderer.Atlas_Staging_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Atlas_Staging_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_Staging_Memory := System.Null_Address;
         end if;

         if Renderer.Atlas_View /= System.Null_Address then
            Vk.Destroy_Image_View
              (device      => Renderer.Device,
               image_View  => Renderer.Atlas_View,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_View := System.Null_Address;
         end if;

         if Renderer.Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler
              (device      => Renderer.Device,
               sampler     => Renderer.Atlas_Sampler,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_Sampler := System.Null_Address;
         end if;

         if Renderer.Atlas_Image /= System.Null_Address then
            Vk.Destroy_Image
              (device      => Renderer.Device,
               image       => Renderer.Atlas_Image,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_Image := System.Null_Address;
         end if;

         if Renderer.Atlas_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Atlas_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Atlas_Memory := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Staging_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer
              (device      => Renderer.Device,
               buffer      => Renderer.Icon_Atlas_Staging_Buffer,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_Staging_Buffer := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Staging_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Icon_Atlas_Staging_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_Staging_Memory := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_View /= System.Null_Address then
            Vk.Destroy_Image_View
              (device      => Renderer.Device,
               image_View  => Renderer.Icon_Atlas_View,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_View := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler
              (device      => Renderer.Device,
               sampler     => Renderer.Icon_Atlas_Sampler,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_Sampler := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Image /= System.Null_Address then
            Vk.Destroy_Image
              (device      => Renderer.Device,
               image       => Renderer.Icon_Atlas_Image,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_Image := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Icon_Atlas_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Icon_Atlas_Memory := System.Null_Address;
         end if;

         if Renderer.Readback_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer
              (device      => Renderer.Device,
               buffer      => Renderer.Readback_Buffer,
               p_Allocator => System.Null_Address);
            Renderer.Readback_Buffer := System.Null_Address;
         end if;

         if Renderer.Readback_Memory /= System.Null_Address then
            Vk.Free_Memory
              (device      => Renderer.Device,
               memory      => Renderer.Readback_Memory,
               p_Allocator => System.Null_Address);
            Renderer.Readback_Memory := System.Null_Address;
         end if;

         if Renderer.Graphics_Pipeline /= System.Null_Address then
            Vk.Destroy_Pipeline
              (device      => Renderer.Device,
               pipeline    => Renderer.Graphics_Pipeline,
               p_Allocator => System.Null_Address);
            Renderer.Graphics_Pipeline := System.Null_Address;
         end if;

         if Renderer.Pipeline_Layout /= System.Null_Address then
            Vk.Destroy_Pipeline_Layout
              (device          => Renderer.Device,
               pipeline_Layout => Renderer.Pipeline_Layout,
               p_Allocator     => System.Null_Address);
            Renderer.Pipeline_Layout := System.Null_Address;
         end if;

         if Renderer.Descriptor_Pool /= System.Null_Address then
            Vk.Destroy_Descriptor_Pool
              (device          => Renderer.Device,
               descriptor_Pool => Renderer.Descriptor_Pool,
               p_Allocator     => System.Null_Address);
            Renderer.Descriptor_Pool := System.Null_Address;
            Renderer.Descriptor_Set := System.Null_Address;
            Renderer.Texture_Binding_Count := 0;
         end if;

         if Renderer.Descriptor_Set_Layout /= System.Null_Address then
            Vk.Destroy_Descriptor_Set_Layout
              (device                => Renderer.Device,
               descriptor_Set_Layout => Renderer.Descriptor_Set_Layout,
               p_Allocator           => System.Null_Address);
            Renderer.Descriptor_Set_Layout := System.Null_Address;
         end if;

         for Index in Renderer.Framebuffers'Range loop
            if Renderer.Framebuffers (Index) /= System.Null_Address then
               Vk.Destroy_Framebuffer
                 (device      => Renderer.Device,
                  framebuffer => Renderer.Framebuffers (Index),
                  p_Allocator => System.Null_Address);
               Renderer.Framebuffers (Index) := System.Null_Address;
            end if;
         end loop;

         if Renderer.Render_Pass /= System.Null_Address then
            Vk.Destroy_Render_Pass
              (device      => Renderer.Device,
               render_Pass => Renderer.Render_Pass,
               p_Allocator => System.Null_Address);
            Renderer.Render_Pass := System.Null_Address;
         end if;

         for Index in Renderer.Image_Views'Range loop
            if Renderer.Image_Views (Index) /= System.Null_Address then
               Vk.Destroy_Image_View
                 (device      => Renderer.Device,
                  image_View  => Renderer.Image_Views (Index),
                  p_Allocator => System.Null_Address);
               Renderer.Image_Views (Index) := System.Null_Address;
            end if;
         end loop;

         if Renderer.Sync_Live then
            if Renderer.In_Flight /= System.Null_Address then
               Vk.Destroy_Fence
                 (device      => Renderer.Device,
                  fence       => Renderer.In_Flight,
                  p_Allocator => System.Null_Address);
               Renderer.In_Flight := System.Null_Address;
            end if;

            if Renderer.Render_Finished /= System.Null_Address then
               Vk.Destroy_Semaphore
                 (device      => Renderer.Device,
                  semaphore   => Renderer.Render_Finished,
                  p_Allocator => System.Null_Address);
               Renderer.Render_Finished := System.Null_Address;
            end if;

            Vk.Destroy_Semaphore
              (device      => Renderer.Device,
               semaphore   => Renderer.Image_Available,
               p_Allocator => System.Null_Address);
            Renderer.Image_Available := System.Null_Address;
            Renderer.Sync_Live := False;
         end if;

         if Renderer.Swapchain_Live then
            Vk.Destroy_Swapchain_KHR
              (device      => Renderer.Device,
               swapchain   => Renderer.Swapchain,
               p_Allocator => System.Null_Address);
            Renderer.Swapchain := System.Null_Address;
            Renderer.Swapchain_Live := False;
         end if;
      else
         Renderer.Image_Available := System.Null_Address;
         Renderer.Render_Finished := System.Null_Address;
         Renderer.In_Flight := System.Null_Address;
         Renderer.Swapchain := System.Null_Address;
         Renderer.Render_Pass := System.Null_Address;
         Renderer.Image_Views := [others => System.Null_Address];
         Renderer.Framebuffers := [others => System.Null_Address];
         Renderer.Command_Pool := System.Null_Address;
         Renderer.Command_Buffers := [others => System.Null_Address];
         Renderer.Pipeline_Layout := System.Null_Address;
         Renderer.Graphics_Pipeline := System.Null_Address;
         Renderer.Descriptor_Set_Layout := System.Null_Address;
         Renderer.Descriptor_Pool := System.Null_Address;
         Renderer.Descriptor_Set := System.Null_Address;
         Renderer.Texture_Binding_Count := 0;
         Renderer.Vertex_Buffer := System.Null_Address;
         Renderer.Vertex_Memory := System.Null_Address;
         Renderer.Atlas_Image := System.Null_Address;
         Renderer.Atlas_Memory := System.Null_Address;
         Renderer.Atlas_View := System.Null_Address;
         Renderer.Atlas_Sampler := System.Null_Address;
         Renderer.Atlas_Staging_Buffer := System.Null_Address;
         Renderer.Atlas_Staging_Memory := System.Null_Address;
         Renderer.Icon_Atlas_Image := System.Null_Address;
         Renderer.Icon_Atlas_Memory := System.Null_Address;
         Renderer.Icon_Atlas_View := System.Null_Address;
         Renderer.Icon_Atlas_Sampler := System.Null_Address;
         Renderer.Icon_Atlas_Staging_Buffer := System.Null_Address;
         Renderer.Icon_Atlas_Staging_Memory := System.Null_Address;
         Renderer.Readback_Buffer := System.Null_Address;
         Renderer.Readback_Memory := System.Null_Address;
         Renderer.Sync_Live := False;
         Renderer.Swapchain_Live := False;
      end if;

      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Image_Count := 0;
      Renderer.Render_Target_Count := 0;
      Renderer.Command_Buffer_Count := 0;
      Renderer.Render_Targets_Live := False;
      Renderer.Descriptor_Live := False;
      Renderer.Texture_Binding_Count := 0;
      Renderer.Pipeline_Live := False;
      Renderer.Vertex_Buffer_Live := False;
      Renderer.Atlas_Texture_Live := False;
      Renderer.Atlas_Staging_Live := False;
      Renderer.Atlas_Initialized := False;
      Renderer.Atlas_Upload_Pending := False;
      Renderer.Icon_Atlas_Texture_Live := False;
      Renderer.Icon_Atlas_Staging_Live := False;
      Renderer.Icon_Atlas_Initialized := False;
      Renderer.Icon_Atlas_Upload_Pending := False;
      Renderer.Commands_Live := False;
      Renderer.Swapchain_Images := [others => System.Null_Address];
      Renderer.Command_Buffers := [others => System.Null_Address];
      Renderer.Current_Image_Index := 0;
      Renderer.Vertex_Buffer_Capacity := 0;
      Renderer.Atlas_Width_Value := 0;
      Renderer.Atlas_Height_Value := 0;
      Renderer.Atlas_Format_Value := Atlas_Texture_None;
      Renderer.Atlas_Staging_Capacity := 0;
      Renderer.Icon_Atlas_Width_Value := 0;
      Renderer.Icon_Atlas_Height_Value := 0;
      Renderer.Icon_Atlas_Format_Value := Atlas_Texture_None;
      Renderer.Icon_Atlas_Staging_Capacity := 0;
      Renderer.Readback_Capacity := 0;
      Renderer.Readback_Bytes := 0;
      Renderer.Readback_Pending := False;
      Renderer.Readback_Ready := False;
      Renderer.Last_Readback_Hash := 0;
   end Destroy_Swapchain_Resources;

   procedure Set_Readback_Enabled
     (Renderer : in out Vulkan_Renderer;
      Enabled  : Boolean) is
   begin
      Renderer.Readback_Enabled := Enabled;
      if not Enabled then
         Renderer.Readback_Pending := False;
         Renderer.Readback_Ready := False;
         Renderer.Readback_Bytes := 0;
         Renderer.Last_Readback_Hash := 0;
      end if;
   end Set_Readback_Enabled;

   function Create_Render_Targets
     (Renderer : in out Vulkan_Renderer;
      Format   : Vk.Format_T)
      return Boolean
   is
      Attachment : aliased Vk.Attachment_Description_T :=
        (flags            => 0,
         format           => Format,
         samples          => Vk.SAMPLE_COUNT_1_BIT,
         load_Op          => Vk.ATTACHMENT_LOAD_OP_CLEAR,
         store_Op         => Vk.ATTACHMENT_STORE_OP_STORE,
         stencil_Load_Op  => Vk.ATTACHMENT_LOAD_OP_DONT_CARE,
         stencil_Store_Op => Vk.ATTACHMENT_STORE_OP_DONT_CARE,
         initial_Layout   => Vk.IMAGE_LAYOUT_UNDEFINED,
         final_Layout     => Image_Layout_Present_Src_KHR);
      Color_Reference : aliased Vk.Attachment_Reference_T :=
        (attachment => 0,
         layout     => Vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
      Subpass : aliased Vk.Subpass_Description_T :=
        (flags                       => 0,
         pipeline_Bind_Point         => Vk.PIPELINE_BIND_POINT_GRAPHICS,
         input_Attachment_Count      => 0,
         p_Input_Attachments         => System.Null_Address,
         color_Attachment_Count      => 1,
         p_Color_Attachments         => Color_Reference'Address,
         p_Resolve_Attachments       => System.Null_Address,
         p_Depth_Stencil_Attachment  => System.Null_Address,
         preserve_Attachment_Count   => 0,
         p_Preserve_Attachments      => System.Null_Address);
      Render_Pass_Info : aliased Vk.Render_Pass_Create_Info_T :=
        (s_Type           => Vk.STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
         p_Next           => System.Null_Address,
         flags            => 0,
         attachment_Count => 1,
         p_Attachments    => Attachment'Address,
         subpass_Count    => 1,
         p_Subpasses      => Subpass'Address,
         dependency_Count => 0,
         p_Dependencies   => System.Null_Address);
      Render_Pass_Handle : aliased Vk.Render_Pass_T := System.Null_Address;
      Result             : Vk.Result_T;
   begin
      Result :=
        Vk.Create_Render_Pass
          (device        => Renderer.Device,
           p_Create_Info => Render_Pass_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Render_Pass => Render_Pass_Handle'Address);

      if Result /= Vk.SUCCESS or else Render_Pass_Handle = System.Null_Address then
         return False;
      end if;

      Renderer.Render_Pass := Render_Pass_Handle;

      for Index in 1 .. Natural (Renderer.Swapchain_Image_Count) loop
         declare
            View_Info : aliased Vk.Image_View_Create_Info_T :=
              (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
               p_Next            => System.Null_Address,
               flags             => 0,
               image             => Renderer.Swapchain_Images (Index),
               view_Type         => Vk.IMAGE_VIEW_TYPE_2D,
               format            => Format,
               components        =>
                 (r => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  g => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  b => Vk.COMPONENT_SWIZZLE_IDENTITY,
                  a => Vk.COMPONENT_SWIZZLE_IDENTITY),
               subresource_Range =>
                 (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                  base_Mip_Level   => 0,
                  level_Count      => 1,
                  base_Array_Layer => 0,
                  layer_Count      => 1));
            View_Handle : aliased Vk.Image_View_T := System.Null_Address;
            Attachment_View : aliased Vk.Image_View_T;
            Framebuffer_Info : aliased Vk.Framebuffer_Create_Info_T;
            Framebuffer_Handle : aliased Vk.Framebuffer_T := System.Null_Address;
         begin
            Result :=
              Vk.Create_Image_View
                (device        => Renderer.Device,
                 p_Create_Info => View_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_View        => View_Handle'Address);

            if Result /= Vk.SUCCESS or else View_Handle = System.Null_Address then
               return False;
            end if;

            Renderer.Image_Views (Index) := View_Handle;
            Attachment_View := View_Handle;
            Framebuffer_Info :=
              (s_Type           => Vk.STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
               p_Next           => System.Null_Address,
               flags            => 0,
               render_Pass      => Renderer.Render_Pass,
               attachment_Count => 1,
               p_Attachments    => Attachment_View'Address,
               width            => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
               height           => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value),
               layers           => 1);
            Result :=
              Vk.Create_Framebuffer
                (device        => Renderer.Device,
                 p_Create_Info => Framebuffer_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Framebuffer => Framebuffer_Handle'Address);

            if Result /= Vk.SUCCESS or else Framebuffer_Handle = System.Null_Address then
               return False;
            end if;

            Renderer.Framebuffers (Index) := Framebuffer_Handle;
         end;
      end loop;

      Renderer.Render_Target_Count := Renderer.Swapchain_Image_Count;
      Renderer.Render_Targets_Live := Renderer.Render_Target_Count = Renderer.Swapchain_Image_Count;
      return Renderer.Render_Targets_Live;
   exception
      when others =>
         return False;
   end Create_Render_Targets;

   function Create_Graphics_Pipeline
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is
      Set_Layouts : aliased Descriptor_Set_Layout_Array_C (1 .. 1) := [1 => Renderer.Descriptor_Set_Layout];
      Vertex_Module_Info : aliased Vk.Shader_Module_Create_Info_T :=
        (s_Type    => Vk.STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
         p_Next    => System.Null_Address,
         flags     => 0,
         code_Size => Interfaces.C.size_t (Vertex_Shader_Code'Size / 8),
         p_Code    => Vertex_Shader_Code (Vertex_Shader_Code'First)'Address);
      Fragment_Module_Info : aliased Vk.Shader_Module_Create_Info_T :=
        (s_Type    => Vk.STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
         p_Next    => System.Null_Address,
         flags     => 0,
         code_Size => Interfaces.C.size_t (Fragment_Shader_Code'Size / 8),
         p_Code    => Fragment_Shader_Code (Fragment_Shader_Code'First)'Address);
      Vertex_Module : aliased Vk.Shader_Module_T := System.Null_Address;
      Fragment_Module : aliased Vk.Shader_Module_T := System.Null_Address;
      Layout_Info : aliased Vk.Pipeline_Layout_Create_Info_T :=
        (s_Type                    => Vk.STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
         p_Next                    => System.Null_Address,
         flags                     => 0,
         set_Layout_Count          => 1,
         p_Set_Layouts             => Set_Layouts'Address,
         push_Constant_Range_Count => 0,
         p_Push_Constant_Ranges    => System.Null_Address);
      Layout_Handle : aliased Vk.Pipeline_Layout_T := System.Null_Address;
      Main_Name : aliased Interfaces.C.char_array := Interfaces.C.To_C ("main");
      Stages : aliased Shader_Stage_Array (1 .. 2);
      Binding : aliased Vertex_Binding_Array (1 .. 1) :=
        [1 =>
           (binding    => 0,
            stride     => Interfaces.Unsigned_32 (Gpu_Vertex_Size),
            input_Rate => Vk.VERTEX_INPUT_RATE_VERTEX)];
      Attributes : aliased Vertex_Attribute_Array (1 .. 2) :=
        [1 =>
           (location => 0,
            binding  => 0,
            format   => Vk.FORMAT_R32G32_SFLOAT,
            offset   => 0),
         2 =>
           (location => 1,
            binding  => 0,
            format   => Vk.FORMAT_R32G32_SFLOAT,
            offset   => Interfaces.Unsigned_32 (2 * Interfaces.C.C_float'Size / 8))];
      Textured_Attributes : aliased Vertex_Attribute_Array (1 .. 5) :=
        [1 =>
           (location => 0,
            binding  => 0,
            format   => Vk.FORMAT_R32G32_SFLOAT,
            offset   => 0),
         2 =>
           (location => 1,
            binding  => 0,
            format   => Vk.FORMAT_R32G32_SFLOAT,
            offset   => Interfaces.Unsigned_32 (2 * Interfaces.C.C_float'Size / 8)),
         3 =>
           (location => 2,
            binding  => 0,
            format   => Vk.FORMAT_R32G32B32A32_SFLOAT,
            offset   => Interfaces.Unsigned_32 (4 * Interfaces.C.C_float'Size / 8)),
         4 =>
           (location => 3,
            binding  => 0,
            format   => Vk.FORMAT_R32_SFLOAT,
            offset   => Interfaces.Unsigned_32 (8 * Interfaces.C.C_float'Size / 8)),
         5 =>
           (location => 4,
            binding  => 0,
            format   => Vk.FORMAT_R32_SFLOAT,
            offset   => Interfaces.Unsigned_32 (9 * Interfaces.C.C_float'Size / 8))];
      Vertex_Input : aliased Vk.Pipeline_Vertex_Input_State_Create_Info_T :=
        (s_Type                           => Vk.STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
         p_Next                           => System.Null_Address,
         flags                            => 0,
         vertex_Binding_Description_Count => 1,
         p_Vertex_Binding_Descriptions    => Binding'Address,
         vertex_Attribute_Description_Count => 5,
         p_Vertex_Attribute_Descriptions    => Textured_Attributes'Address);
      Input_Assembly : aliased Vk.Pipeline_Input_Assembly_State_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         topology                 => Vk.PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
         primitive_Restart_Enable => 0);
      Framebuffer_Width  : constant Interfaces.C.C_float :=
        Interfaces.C.C_float (Renderer.Frame_Width_Value);
      Framebuffer_Height : constant Interfaces.C.C_float :=
        Interfaces.C.C_float (Renderer.Frame_Height_Value);
      Viewport : aliased Vk.Viewport_T :=
        (x         => 0.0,
         y         => Framebuffer_Height,
         width     => Framebuffer_Width,
         height    => -Framebuffer_Height,
         min_Depth => 0.0,
         max_Depth => 1.0);
      Scissor : aliased Vk.Rect2_D_T :=
        (offset => (x => 0, y => 0),
         extent =>
           (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
            height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value)));
      Viewport_State : aliased Vk.Pipeline_Viewport_State_Create_Info_T :=
        (s_Type         => Vk.STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
         p_Next         => System.Null_Address,
         flags          => 0,
         viewport_Count => 1,
         p_Viewports    => Viewport'Address,
         scissor_Count  => 1,
         p_Scissors     => Scissor'Address);
      Rasterization : aliased Vk.Pipeline_Rasterization_State_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         depth_Clamp_Enable       => 0,
         rasterizer_Discard_Enable => 0,
         polygon_Mode             => Vk.POLYGON_MODE_FILL,
         cull_Mode                => Vk.CULL_MODE_NONE,
         front_Face               => Vk.FRONT_FACE_COUNTER_CLOCKWISE,
         depth_Bias_Enable        => 0,
         depth_Bias_Constant_Factor => 0.0,
         depth_Bias_Clamp         => 0.0,
         depth_Bias_Slope_Factor  => 0.0,
         line_Width               => 1.0);
      Multisample : aliased Vk.Pipeline_Multisample_State_Create_Info_T :=
        (s_Type                  => Vk.STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
         p_Next                  => System.Null_Address,
         flags                   => 0,
         rasterization_Samples   => Vk.SAMPLE_COUNT_1_BIT,
         sample_Shading_Enable   => 0,
         min_Sample_Shading      => 1.0,
         p_Sample_Mask           => System.Null_Address,
         alpha_To_Coverage_Enable => 0,
         alpha_To_One_Enable     => 0);
      Blend_Attachment : aliased Vk.Pipeline_Color_Blend_Attachment_State_T :=
        (blend_Enable         => 1,
         src_Color_Blend_Factor => Vk.BLEND_FACTOR_SRC_ALPHA,
         dst_Color_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
         color_Blend_Op      => Vk.BLEND_OP_ADD,
         src_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE,
         dst_Alpha_Blend_Factor => Vk.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
         alpha_Blend_Op      => Vk.BLEND_OP_ADD,
         color_Write_Mask    =>
           Vk.COLOR_COMPONENT_R_BIT or Vk.COLOR_COMPONENT_G_BIT or
           Vk.COLOR_COMPONENT_B_BIT or Vk.COLOR_COMPONENT_A_BIT);
      Color_Blend : aliased Vk.Pipeline_Color_Blend_State_Create_Info_T :=
        (s_Type           => Vk.STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
         p_Next           => System.Null_Address,
         flags            => 0,
         logic_Op_Enable  => 0,
         logic_Op         => Vk.LOGIC_OP_COPY,
         attachment_Count => 1,
         p_Attachments    => Blend_Attachment'Address,
         blend_Constants  => [0.0, 0.0, 0.0, 0.0]);
      Pipeline_Info : aliased Vk.Graphics_Pipeline_Create_Info_T;
      Pipeline_Handle : aliased Vk.Pipeline_T := System.Null_Address;
      Result : Vk.Result_T;
   begin
      Result :=
        Vk.Create_Shader_Module
          (device          => Renderer.Device,
           p_Create_Info   => Vertex_Module_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Shader_Module => Vertex_Module'Address);

      if Result /= Vk.SUCCESS or else Vertex_Module = System.Null_Address then
         return False;
      end if;

      Result :=
        Vk.Create_Shader_Module
          (device          => Renderer.Device,
           p_Create_Info   => Fragment_Module_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Shader_Module => Fragment_Module'Address);

      if Result /= Vk.SUCCESS or else Fragment_Module = System.Null_Address then
         Vk.Destroy_Shader_Module (Renderer.Device, Vertex_Module, System.Null_Address);
         return False;
      end if;

      Result :=
        Vk.Create_Pipeline_Layout
          (device            => Renderer.Device,
           p_Create_Info     => Layout_Info'Address,
           p_Allocator       => System.Null_Address,
           p_Pipeline_Layout => Layout_Handle'Address);

      if Result /= Vk.SUCCESS or else Layout_Handle = System.Null_Address then
         Vk.Destroy_Shader_Module (Renderer.Device, Fragment_Module, System.Null_Address);
         Vk.Destroy_Shader_Module (Renderer.Device, Vertex_Module, System.Null_Address);
         return False;
      end if;

      Stages :=
        [1 =>
           (s_Type                => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            p_Next                => System.Null_Address,
            flags                 => 0,
            stage                 => Vk.SHADER_STAGE_VERTEX_BIT,
            module                => Vertex_Module,
            p_Name                => Main_Name (Main_Name'First)'Address,
            p_Specialization_Info => System.Null_Address),
         2 =>
           (s_Type                => Vk.STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            p_Next                => System.Null_Address,
            flags                 => 0,
            stage                 => Vk.SHADER_STAGE_FRAGMENT_BIT,
            module                => Fragment_Module,
            p_Name                => Main_Name (Main_Name'First)'Address,
            p_Specialization_Info => System.Null_Address)];
      Pipeline_Info :=
        (s_Type                 => Vk.STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
         p_Next                 => System.Null_Address,
         flags                  => 0,
         stage_Count            => 2,
         p_Stages               => Stages'Address,
         p_Vertex_Input_State   => Vertex_Input'Address,
         p_Input_Assembly_State => Input_Assembly'Address,
         p_Tessellation_State   => System.Null_Address,
         p_Viewport_State       => Viewport_State'Address,
         p_Rasterization_State  => Rasterization'Address,
         p_Multisample_State    => Multisample'Address,
         p_Depth_Stencil_State  => System.Null_Address,
         p_Color_Blend_State    => Color_Blend'Address,
         p_Dynamic_State        => System.Null_Address,
         layout                 => Layout_Handle,
         render_Pass            => Renderer.Render_Pass,
         subpass                => 0,
         base_Pipeline_Handle   => System.Null_Address,
         base_Pipeline_Index    => Interfaces.Integer_32'(-1));
      Result :=
        Vk.Create_Graphics_Pipelines
          (device            => Renderer.Device,
           pipeline_Cache    => System.Null_Address,
           create_Info_Count => 1,
           p_Create_Infos    => Pipeline_Info'Address,
           p_Allocator       => System.Null_Address,
           p_Pipelines       => Pipeline_Handle'Address);

      Vk.Destroy_Shader_Module (Renderer.Device, Fragment_Module, System.Null_Address);
      Vk.Destroy_Shader_Module (Renderer.Device, Vertex_Module, System.Null_Address);

      if Result /= Vk.SUCCESS or else Pipeline_Handle = System.Null_Address then
         Vk.Destroy_Pipeline_Layout
           (device          => Renderer.Device,
            pipeline_Layout => Layout_Handle,
            p_Allocator     => System.Null_Address);
         return False;
      end if;

      Renderer.Pipeline_Layout := Layout_Handle;
      Renderer.Graphics_Pipeline := Pipeline_Handle;
      Renderer.Pipeline_Live := True;
      return True;
   exception
      when others =>
         return False;
   end Create_Graphics_Pipeline;

   function Create_Descriptor_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is
      Binding : aliased Descriptor_Set_Layout_Binding_Array (1 .. 2) :=
        [1 =>
           (binding              => 0,
            descriptor_Type      => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptor_Count     => 1,
            stage_Flags          => Vk.SHADER_STAGE_FRAGMENT_BIT,
            p_Immutable_Samplers => System.Null_Address),
         2 =>
           (binding              => 1,
            descriptor_Type      => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptor_Count     => 1,
            stage_Flags          => Vk.SHADER_STAGE_FRAGMENT_BIT,
            p_Immutable_Samplers => System.Null_Address)];
      Layout_Info : aliased Vk.Descriptor_Set_Layout_Create_Info_T :=
        (s_Type        => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
         p_Next        => System.Null_Address,
         flags         => 0,
         binding_Count => Interfaces.Unsigned_32 (Binding'Length),
         p_Bindings    => Binding'Address);
      Pool_Size : aliased Descriptor_Pool_Size_Array (1 .. 1) :=
        [1 =>
           (type_F           => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            descriptor_Count => Interfaces.Unsigned_32 (Binding'Length))];
      Pool_Info : aliased Vk.Descriptor_Pool_Create_Info_T :=
        (s_Type          => Vk.STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
         p_Next          => System.Null_Address,
         flags           => 0,
         max_Sets        => 1,
         pool_Size_Count => 1,
         p_Pool_Sizes    => Pool_Size'Address);
      Layout_Handle : aliased Vk.Descriptor_Set_Layout_T := System.Null_Address;
      Pool_Handle   : aliased Vk.Descriptor_Pool_T := System.Null_Address;
      Set_Layouts   : aliased Descriptor_Set_Layout_Array_C (1 .. 1);
      Allocate_Info : aliased Vk.Descriptor_Set_Allocate_Info_T;
      Sets          : aliased Descriptor_Set_Array_C (1 .. 1);
      Result        : Vk.Result_T;
   begin
      Result :=
        Vk.Create_Descriptor_Set_Layout
          (device        => Renderer.Device,
           p_Create_Info => Layout_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Set_Layout  => Layout_Handle'Address);

      if Result /= Vk.SUCCESS or else Layout_Handle = System.Null_Address then
         return False;
      end if;

      Result :=
        Vk.Create_Descriptor_Pool
          (device            => Renderer.Device,
           p_Create_Info     => Pool_Info'Address,
           p_Allocator       => System.Null_Address,
           p_Descriptor_Pool => Pool_Handle'Address);

      if Result /= Vk.SUCCESS or else Pool_Handle = System.Null_Address then
         Vk.Destroy_Descriptor_Set_Layout (Renderer.Device, Layout_Handle, System.Null_Address);
         return False;
      end if;

      Set_Layouts := [1 => Layout_Handle];
      Allocate_Info :=
        (s_Type                => Vk.STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
         p_Next                => System.Null_Address,
         descriptor_Pool       => Pool_Handle,
         descriptor_Set_Count  => 1,
         p_Set_Layouts         => Set_Layouts'Address);
      Result :=
        Vk.Allocate_Descriptor_Sets
          (device              => Renderer.Device,
           p_Allocate_Info     => Allocate_Info'Address,
           p_Descriptor_Sets   => Sets'Address);

      if Result /= Vk.SUCCESS or else Sets (1) = System.Null_Address then
         Vk.Destroy_Descriptor_Pool (Renderer.Device, Pool_Handle, System.Null_Address);
         Vk.Destroy_Descriptor_Set_Layout (Renderer.Device, Layout_Handle, System.Null_Address);
         return False;
      end if;

      Renderer.Descriptor_Set_Layout := Layout_Handle;
      Renderer.Descriptor_Pool := Pool_Handle;
      Renderer.Descriptor_Set := Sets (1);
      Renderer.Descriptor_Live := True;
      Renderer.Texture_Binding_Count := Binding'Length;
      return True;
   exception
      when others =>
         return False;
   end Create_Descriptor_Resources;

   function Create_Command_Resources
     (Renderer : in out Vulkan_Renderer)
      return Boolean
   is
      Pool_Info : aliased Vk.Command_Pool_Create_Info_T :=
        (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
         p_Next             => System.Null_Address,
         flags              => 0,
         queue_Family_Index => Renderer.Queue_Family_Index);
      Pool_Handle : aliased Vk.Command_Pool_T := System.Null_Address;
      Buffers     : aliased Command_Buffer_Array_C (1 .. Max_Swapchain_Images);
      Allocate_Info : aliased Vk.Command_Buffer_Allocate_Info_T;
      Result      : Vk.Result_T;
   begin
      Result :=
        Vk.Create_Command_Pool
          (device         => Renderer.Device,
           p_Create_Info  => Pool_Info'Address,
           p_Allocator    => System.Null_Address,
           p_Command_Pool => Pool_Handle'Address);

      if Result /= Vk.SUCCESS or else Pool_Handle = System.Null_Address then
         return False;
      end if;

      Renderer.Command_Pool := Pool_Handle;
      Allocate_Info :=
        (s_Type               => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
         p_Next               => System.Null_Address,
         command_Pool         => Renderer.Command_Pool,
         level                => Vk.COMMAND_BUFFER_LEVEL_PRIMARY,
         command_Buffer_Count => Renderer.Render_Target_Count);
      Result :=
        Vk.Allocate_Command_Buffers
          (device            => Renderer.Device,
           p_Allocate_Info   => Allocate_Info'Address,
           p_Command_Buffers => Buffers (Buffers'First)'Address);

      if Result /= Vk.SUCCESS then
         return False;
      end if;

      for Index in 1 .. Natural (Renderer.Render_Target_Count) loop
         Renderer.Command_Buffers (Index) := Buffers (Index);
      end loop;

      Renderer.Command_Buffer_Count := Renderer.Render_Target_Count;
      return True;
   exception
      when others =>
         return False;
   end Create_Command_Resources;

   function Ensure_Vertex_Buffer
     (Renderer : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean
   is
      Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         size                     => Gpu_Vertex_Buffer_Size,
         usage                    => Vk.BUFFER_USAGE_VERTEX_BUFFER_BIT,
         sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address);
      Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
      Requirements  : aliased Vk.Memory_Requirements_T;
      Memory_Type   : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      Result        : Vk.Result_T;
   begin
      if Vertex_Count = 0 then
         return True;
      elsif Vertex_Count > Max_Batch_Vertices then
         return False;
      elsif Renderer.Vertex_Buffer_Live and then Renderer.Vertex_Buffer_Capacity >= Vertex_Count then
         return True;
      end if;

      if Renderer.Vertex_Buffer /= System.Null_Address then
         Vk.Destroy_Buffer
           (device      => Renderer.Device,
            buffer      => Renderer.Vertex_Buffer,
            p_Allocator => System.Null_Address);
         Renderer.Vertex_Buffer := System.Null_Address;
      end if;

      if Renderer.Vertex_Memory /= System.Null_Address then
         Vk.Free_Memory
           (device      => Renderer.Device,
            memory      => Renderer.Vertex_Memory,
            p_Allocator => System.Null_Address);
         Renderer.Vertex_Memory := System.Null_Address;
      end if;

      Renderer.Vertex_Buffer_Live := False;
      Renderer.Vertex_Buffer_Capacity := 0;
      Result :=
        Vk.Create_Buffer
          (device        => Renderer.Device,
           p_Create_Info => Buffer_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Buffer      => Buffer_Handle'Address);

      if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
         return False;
      end if;

      Vk.Get_Buffer_Memory_Requirements
        (device                => Renderer.Device,
         buffer                => Buffer_Handle,
         p_Memory_Requirements => Requirements'Address);

      if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Allocate_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next            => System.Null_Address,
         allocation_Size   => Requirements.size,
         memory_Type_Index => Memory_Type);
      Result :=
        Vk.Allocate_Memory
          (device          => Renderer.Device,
           p_Allocate_Info => Allocate_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Memory        => Memory_Handle'Address);

      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Result :=
        Vk.Bind_Buffer_Memory
          (device        => Renderer.Device,
           buffer        => Buffer_Handle,
           memory        => Memory_Handle,
           memory_Offset => 0);

      if Result /= Vk.SUCCESS then
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Renderer.Vertex_Buffer := Buffer_Handle;
      Renderer.Vertex_Memory := Memory_Handle;
      Renderer.Vertex_Buffer_Capacity := Max_Batch_Vertices;
      Renderer.Vertex_Buffer_Live := True;
      return True;
   exception
      when others =>
         return False;
   end Ensure_Vertex_Buffer;

   function Upload_Vertices
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean
   is
      Count       : constant Natural := Natural (Batch.Vertices.Length);
      Mapped_Data : aliased System.Address := System.Null_Address;
      Result      : Vk.Result_T;
   begin
      if not Ensure_Vertex_Buffer (Renderer, Count) then
         return False;
      elsif Count = 0 then
         return True;
      end if;

      Result :=
        Vk.Map_Memory
          (device  => Renderer.Device,
           memory  => Renderer.Vertex_Memory,
           offset  => 0,
           size    => Interfaces.Unsigned_64 (Count) * Gpu_Vertex_Size,
           flags   => 0,
           pp_Data => Mapped_Data'Address);

      if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
         return False;
      end if;

      declare
         Mapped : constant Gpu_Vertex_Buffer_Conversions.Object_Pointer :=
           Gpu_Vertex_Buffer_Conversions.To_Pointer (Mapped_Data);
         Index  : Positive := 1;
      begin
         for Source of Batch.Vertices loop
            declare
               Packed : Gpu_Vertex := Color_To_Vertex (Source.Color);
            begin
               Packed.X := Interfaces.C.C_float (Source.X);
               Packed.Y := Interfaces.C.C_float (Source.Y);
               Packed.U := Interfaces.C.C_float (Source.U);
               Packed.V := Interfaces.C.C_float (Source.V);
               Packed.Textured := (if Source.Textured then 1.0 else 0.0);
               Packed.Texture := Interfaces.C.C_float (Texture_Source'Pos (Source.Texture));
               Mapped.all (Index) := Packed;
               Index := Index + 1;
            end;
         end loop;
      end;

      Vk.Unmap_Memory
        (device => Renderer.Device,
         memory => Renderer.Vertex_Memory);
      return True;
   exception
      when others =>
         if Mapped_Data /= System.Null_Address then
            Vk.Unmap_Memory
              (device => Renderer.Device,
               memory => Renderer.Vertex_Memory);
         end if;

         return False;
   end Upload_Vertices;

   function Ensure_Readback_Buffer
     (Renderer : in out Vulkan_Renderer;
      Byte_Count : Natural)
      return Boolean
   is
      Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         size                     => Interfaces.Unsigned_64 (Byte_Count),
         usage                    => Vk.BUFFER_USAGE_TRANSFER_DST_BIT,
         sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices   => System.Null_Address);
      Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
      Requirements  : aliased Vk.Memory_Requirements_T;
      Memory_Type   : Interfaces.Unsigned_32 := 0;
      Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
      Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
      Result        : Vk.Result_T;
   begin
      if Byte_Count = 0 or else Byte_Count > Max_Readback_Bytes then
         return False;
      elsif Renderer.Readback_Buffer /= System.Null_Address
        and then Renderer.Readback_Memory /= System.Null_Address
        and then Renderer.Readback_Capacity >= Byte_Count
      then
         Renderer.Readback_Bytes := Byte_Count;
         return True;
      end if;

      if Renderer.Readback_Buffer /= System.Null_Address then
         Vk.Destroy_Buffer (Renderer.Device, Renderer.Readback_Buffer, System.Null_Address);
         Renderer.Readback_Buffer := System.Null_Address;
      end if;
      if Renderer.Readback_Memory /= System.Null_Address then
         Vk.Free_Memory (Renderer.Device, Renderer.Readback_Memory, System.Null_Address);
         Renderer.Readback_Memory := System.Null_Address;
      end if;

      Renderer.Readback_Capacity := 0;
      Renderer.Readback_Bytes := 0;
      Renderer.Readback_Pending := False;
      Renderer.Readback_Ready := False;
      Result :=
        Vk.Create_Buffer
          (device        => Renderer.Device,
           p_Create_Info => Buffer_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Buffer      => Buffer_Handle'Address);

      if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
         return False;
      end if;

      Vk.Get_Buffer_Memory_Requirements
        (device                => Renderer.Device,
         buffer                => Buffer_Handle,
         p_Memory_Requirements => Requirements'Address);

      if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Allocate_Info :=
        (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
         p_Next            => System.Null_Address,
         allocation_Size   => Requirements.size,
         memory_Type_Index => Memory_Type);
      Result :=
        Vk.Allocate_Memory
          (device          => Renderer.Device,
           p_Allocate_Info => Allocate_Info'Address,
           p_Allocator     => System.Null_Address,
           p_Memory        => Memory_Handle'Address);

      if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Result := Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0);
      if Result /= Vk.SUCCESS then
         Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
         Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
         return False;
      end if;

      Renderer.Readback_Buffer := Buffer_Handle;
      Renderer.Readback_Memory := Memory_Handle;
      Renderer.Readback_Capacity := Byte_Count;
      Renderer.Readback_Bytes := Byte_Count;
      return True;
   exception
      when others =>
         return False;
   end Ensure_Readback_Buffer;

   procedure Capture_Completed_Readback
     (Renderer : in out Vulkan_Renderer)
   is
      Mapped_Data : aliased System.Address := System.Null_Address;
      Result      : Vk.Result_T;
      Hash        : Interfaces.Unsigned_32 := 2_166_136_261;

      procedure Mix
        (Value : Interfaces.Unsigned_8) is
      begin
         Hash := (Hash xor Interfaces.Unsigned_32 (Value)) * 16_777_619;
      end Mix;
   begin
      if not Renderer.Readback_Pending
        or else Renderer.Readback_Memory = System.Null_Address
        or else Renderer.Readback_Bytes = 0
        or else Renderer.Readback_Bytes > Max_Readback_Bytes
      then
         return;
      end if;

      Result :=
        Vk.Map_Memory
          (device  => Renderer.Device,
           memory  => Renderer.Readback_Memory,
           offset  => 0,
           size    => Interfaces.Unsigned_64 (Renderer.Readback_Bytes),
           flags   => 0,
           pp_Data => Mapped_Data'Address);

      if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
         Renderer.Readback_Pending := False;
         Renderer.Readback_Ready := False;
         return;
      end if;

      declare
         Bytes : constant Readback_Byte_Array_Conversions.Object_Pointer :=
           Readback_Byte_Array_Conversions.To_Pointer (Mapped_Data);
      begin
         for Index in 1 .. Renderer.Readback_Bytes loop
            Mix (Bytes.all (Index));
         end loop;
      end;

      Vk.Unmap_Memory (Renderer.Device, Renderer.Readback_Memory);
      Renderer.Last_Readback_Hash := Hash;
      Renderer.Readback_Ready := True;
      Renderer.Readback_Pending := False;
   exception
      when others =>
         if Mapped_Data /= System.Null_Address then
            Vk.Unmap_Memory (Renderer.Device, Renderer.Readback_Memory);
         end if;
         Renderer.Readback_Pending := False;
         Renderer.Readback_Ready := False;
   end Capture_Completed_Readback;

   function Upload_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean
   is
      Use_Batch_Atlas : constant Boolean :=
        Batch.Text_Atlas_Used
        and then
          (Batch.Atlas_Dirty
           or else not Renderer.Atlas_Texture_Live
           or else Renderer.Atlas_Width_Value /= Batch.Atlas_Width
           or else Renderer.Atlas_Height_Value /= Batch.Atlas_Height
           or else Renderer.Atlas_Format_Value /= Atlas_Texture_R8);
      Use_Icon_Atlas  : constant Boolean :=
        (not Use_Batch_Atlas) and then (not Batch.Text_Atlas_Used) and then Batch.Icon_Atlas_Dirty;
      Upload_Format   : constant Atlas_Texture_Format :=
        (if Use_Batch_Atlas then Atlas_Texture_R8
         elsif Use_Icon_Atlas and then Batch.Icon_Atlas_Channels = 4 then Atlas_Texture_RGBA8
         elsif Use_Icon_Atlas then Atlas_Texture_R8
         else Atlas_Texture_None);
      Vulkan_Format   : constant Vk.Format_T :=
        (if Upload_Format = Atlas_Texture_RGBA8 then Format_R8G8B8A8_Unorm else Vk.FORMAT_R8_UNORM);
      Actual_Width : constant Natural :=
        (if Use_Batch_Atlas then Batch.Atlas_Width elsif Use_Icon_Atlas then Batch.Icon_Atlas_Width else 1);
      Actual_Height : constant Natural :=
        (if Use_Batch_Atlas then Batch.Atlas_Height elsif Use_Icon_Atlas then Batch.Icon_Atlas_Height else 1);
      Bytes : constant Natural :=
        (if Use_Batch_Atlas then Batch.Atlas_Bytes elsif Use_Icon_Atlas then Batch.Icon_Atlas_Bytes else 1);
      Pixel_Address : constant System.Address :=
        (if Use_Batch_Atlas then Batch.Atlas_Pixels else Fallback_Atlas_Pixel'Address);
      Needs_New_Texture : constant Boolean :=
        not Renderer.Atlas_Texture_Live
        or else Renderer.Atlas_Width_Value /= Actual_Width
        or else Renderer.Atlas_Height_Value /= Actual_Height
        or else Renderer.Atlas_Format_Value /= Upload_Format;
      Result : Vk.Result_T;
   begin
      if not Use_Batch_Atlas
        and then not Use_Icon_Atlas
        and then Renderer.Atlas_Texture_Live
      then
         return True;
      elsif Pixel_Address = System.Null_Address
        or else Actual_Width = 0
        or else Actual_Height = 0
        or else Bytes = 0
        or else Bytes > Max_Atlas_Bytes
        or else (Use_Icon_Atlas and then Natural (Batch.Icon_Atlas_Pixels.Length) /= Bytes)
      then
         return False;
      end if;

      if Needs_New_Texture then
         if Renderer.Atlas_View /= System.Null_Address then
            Vk.Destroy_Image_View (Renderer.Device, Renderer.Atlas_View, System.Null_Address);
            Renderer.Atlas_View := System.Null_Address;
         end if;

         if Renderer.Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler (Renderer.Device, Renderer.Atlas_Sampler, System.Null_Address);
            Renderer.Atlas_Sampler := System.Null_Address;
         end if;

         if Renderer.Atlas_Image /= System.Null_Address then
            Vk.Destroy_Image (Renderer.Device, Renderer.Atlas_Image, System.Null_Address);
            Renderer.Atlas_Image := System.Null_Address;
         end if;

         if Renderer.Atlas_Memory /= System.Null_Address then
            Vk.Free_Memory (Renderer.Device, Renderer.Atlas_Memory, System.Null_Address);
            Renderer.Atlas_Memory := System.Null_Address;
         end if;

         Renderer.Atlas_Texture_Live := False;
         Renderer.Atlas_Initialized := False;

         declare
            Image_Info : aliased Vk.Image_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               image_Type               => Vk.IMAGE_TYPE_2D,
               format                   => Vulkan_Format,
               extent                   =>
                 (width  => Interfaces.Unsigned_32 (Actual_Width),
                  height => Interfaces.Unsigned_32 (Actual_Height),
                  depth  => 1),
               mip_Levels               => 1,
               array_Layers             => 1,
               samples                  => Vk.SAMPLE_COUNT_1_BIT,
               tiling                   => Vk.IMAGE_TILING_OPTIMAL,
               usage                    => Vk.IMAGE_USAGE_TRANSFER_DST_BIT or Vk.IMAGE_USAGE_SAMPLED_BIT,
               sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices   => System.Null_Address,
               initial_Layout           => Vk.IMAGE_LAYOUT_UNDEFINED);
            Image_Handle : aliased Vk.Image_T := System.Null_Address;
            Requirements : aliased Vk.Memory_Requirements_T;
            Memory_Type  : Interfaces.Unsigned_32 := 0;
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
            Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
            View_Info : aliased Vk.Image_View_Create_Info_T;
            View_Handle : aliased Vk.Image_View_T := System.Null_Address;
            Sampler_Info : aliased Vk.Sampler_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               mag_Filter               => Vk.FILTER_NEAREST,
               min_Filter               => Vk.FILTER_NEAREST,
               mipmap_Mode              => Vk.SAMPLER_MIPMAP_MODE_NEAREST,
               address_Mode_U           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               address_Mode_V           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               address_Mode_W           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               mip_Lod_Bias             => 0.0,
               anisotropy_Enable        => 0,
               max_Anisotropy           => 1.0,
               compare_Enable           => 0,
               compare_Op               => Vk.COMPARE_OP_ALWAYS,
               min_Lod                  => 0.0,
               max_Lod                  => 0.0,
               border_Color             => Vk.BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
               unnormalized_Coordinates => 0);
            Sampler_Handle : aliased Vk.Sampler_T := System.Null_Address;
         begin
            Result :=
              Vk.Create_Image
                (device        => Renderer.Device,
                 p_Create_Info => Image_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Image       => Image_Handle'Address);

            if Result /= Vk.SUCCESS or else Image_Handle = System.Null_Address then
               return False;
            end if;

            Vk.Get_Image_Memory_Requirements (Renderer.Device, Image_Handle, Requirements'Address);
            if not Any_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Allocate_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next            => System.Null_Address,
               allocation_Size   => Requirements.size,
               memory_Type_Index => Memory_Type);
            Result :=
              Vk.Allocate_Memory
                (device          => Renderer.Device,
                 p_Allocate_Info => Allocate_Info'Address,
                 p_Allocator     => System.Null_Address,
                 p_Memory        => Memory_Handle'Address);

            if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            if Vk.Bind_Image_Memory (Renderer.Device, Image_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            View_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
               p_Next            => System.Null_Address,
               flags             => 0,
               image             => Image_Handle,
               view_Type         => Vk.IMAGE_VIEW_TYPE_2D,
               format            => Vulkan_Format,
               components        =>
                 (r => Vk.COMPONENT_SWIZZLE_R,
                  g =>
                    (if Upload_Format = Atlas_Texture_RGBA8
                     then Vk.COMPONENT_SWIZZLE_G
                     else Vk.COMPONENT_SWIZZLE_R),
                  b =>
                    (if Upload_Format = Atlas_Texture_RGBA8
                     then Vk.COMPONENT_SWIZZLE_B
                     else Vk.COMPONENT_SWIZZLE_R),
                  a =>
                    (if Upload_Format = Atlas_Texture_RGBA8
                     then Vk.COMPONENT_SWIZZLE_A
                     else Vk.COMPONENT_SWIZZLE_R)),
               subresource_Range =>
                 (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                  base_Mip_Level   => 0,
                  level_Count      => 1,
                  base_Array_Layer => 0,
                  layer_Count      => 1));
            Result :=
              Vk.Create_Image_View
                (device        => Renderer.Device,
                 p_Create_Info => View_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_View        => View_Handle'Address);

            if Result /= Vk.SUCCESS or else View_Handle = System.Null_Address then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Result :=
              Vk.Create_Sampler
                (device        => Renderer.Device,
                 p_Create_Info => Sampler_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Sampler     => Sampler_Handle'Address);

            if Result /= Vk.SUCCESS or else Sampler_Handle = System.Null_Address then
               Vk.Destroy_Image_View (Renderer.Device, View_Handle, System.Null_Address);
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Renderer.Atlas_Image := Image_Handle;
            Renderer.Atlas_Memory := Memory_Handle;
            Renderer.Atlas_View := View_Handle;
            Renderer.Atlas_Sampler := Sampler_Handle;
            Renderer.Atlas_Width_Value := Actual_Width;
            Renderer.Atlas_Height_Value := Actual_Height;
            Renderer.Atlas_Format_Value := Upload_Format;
            Renderer.Atlas_Texture_Live := True;
         end;
      end if;

      if not Renderer.Atlas_Staging_Live or else Renderer.Atlas_Staging_Capacity < Bytes then
         if Renderer.Atlas_Staging_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer (Renderer.Device, Renderer.Atlas_Staging_Buffer, System.Null_Address);
            Renderer.Atlas_Staging_Buffer := System.Null_Address;
         end if;

         if Renderer.Atlas_Staging_Memory /= System.Null_Address then
            Vk.Free_Memory (Renderer.Device, Renderer.Atlas_Staging_Memory, System.Null_Address);
            Renderer.Atlas_Staging_Memory := System.Null_Address;
         end if;

         declare
            Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               size                     => Interfaces.Unsigned_64 (Bytes),
               usage                    => Vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
               sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices   => System.Null_Address);
            Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
            Requirements  : aliased Vk.Memory_Requirements_T;
            Memory_Type   : Interfaces.Unsigned_32 := 0;
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
            Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
         begin
            Result :=
              Vk.Create_Buffer
                (device        => Renderer.Device,
                 p_Create_Info => Buffer_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Buffer      => Buffer_Handle'Address);

            if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
               return False;
            end if;

            Vk.Get_Buffer_Memory_Requirements (Renderer.Device, Buffer_Handle, Requirements'Address);
            if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            Allocate_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next            => System.Null_Address,
               allocation_Size   => Requirements.size,
               memory_Type_Index => Memory_Type);
            Result :=
              Vk.Allocate_Memory
                (device          => Renderer.Device,
                 p_Allocate_Info => Allocate_Info'Address,
                 p_Allocator     => System.Null_Address,
                 p_Memory        => Memory_Handle'Address);

            if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            if Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            Renderer.Atlas_Staging_Buffer := Buffer_Handle;
            Renderer.Atlas_Staging_Memory := Memory_Handle;
            Renderer.Atlas_Staging_Capacity := Bytes;
            Renderer.Atlas_Staging_Live := True;
         end;
      end if;

      declare
         Mapped_Data : aliased System.Address := System.Null_Address;
      begin
         Result :=
           Vk.Map_Memory
             (device  => Renderer.Device,
              memory  => Renderer.Atlas_Staging_Memory,
              offset  => 0,
              size    => Interfaces.Unsigned_64 (Bytes),
              flags   => 0,
              pp_Data => Mapped_Data'Address);

         if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
            return False;
         end if;

         declare
            Target : constant Byte_Array_Conversions.Object_Pointer :=
              Byte_Array_Conversions.To_Pointer (Mapped_Data);
         begin
            if Use_Icon_Atlas then
               for Index in 1 .. Bytes loop
                  Target.all (Index) := Batch.Icon_Atlas_Pixels.Element (Index);
               end loop;
            else
               declare
                  Source : constant Byte_Array_Conversions.Object_Pointer :=
                    Byte_Array_Conversions.To_Pointer (Pixel_Address);
               begin
                  for Index in 1 .. Bytes loop
                     Target.all (Index) := Source.all (Index);
                  end loop;
               end;
            end if;
         end;

         Vk.Unmap_Memory (Renderer.Device, Renderer.Atlas_Staging_Memory);
      end;

      declare
         Image_Info : aliased Vk.Descriptor_Image_Info_T :=
           (sampler      => Renderer.Atlas_Sampler,
            image_View   => Renderer.Atlas_View,
            image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
         Write : aliased Vk.Write_Descriptor_Set_T :=
           (s_Type                => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            p_Next                => System.Null_Address,
            dst_Set               => Renderer.Descriptor_Set,
            dst_Binding           => 0,
            dst_Array_Element     => 0,
            descriptor_Count      => 1,
            descriptor_Type       => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            p_Image_Info          => Image_Info'Address,
            p_Buffer_Info         => System.Null_Address,
            p_Texel_Buffer_View   => System.Null_Address);
      begin
         Vk.Update_Descriptor_Sets
           (device                 => Renderer.Device,
            descriptor_Write_Count => 1,
            p_Descriptor_Writes    => Write'Address,
            descriptor_Copy_Count  => 0,
            p_Descriptor_Copies    => System.Null_Address);
      end;

      Renderer.Atlas_Upload_Pending := True;
      return True;
   exception
      when others =>
         return False;
   end Upload_Atlas;

   function Upload_Icon_Atlas
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Boolean
   is
      Upload_Format : constant Atlas_Texture_Format := Icon_Upload_Texture_Format (Batch);
      Vulkan_Format : constant Vk.Format_T :=
        (if Upload_Format = Atlas_Texture_RGBA8 then Format_R8G8B8A8_Unorm else Vk.FORMAT_R8_UNORM);
      Bytes : constant Natural := Batch.Icon_Atlas_Bytes;
      Needs_New_Texture : constant Boolean :=
        not Renderer.Icon_Atlas_Texture_Live
        or else Renderer.Icon_Atlas_Width_Value /= Batch.Icon_Atlas_Width
        or else Renderer.Icon_Atlas_Height_Value /= Batch.Icon_Atlas_Height
        or else Renderer.Icon_Atlas_Format_Value /= Upload_Format;
      Result : Vk.Result_T;
   begin
      if not Batch.Icon_Atlas_Dirty and then Renderer.Icon_Atlas_Texture_Live then
         return True;
      elsif not Batch.Icon_Atlas_Dirty
        or else Upload_Format = Atlas_Texture_None
        or else Batch.Icon_Atlas_Width = 0
        or else Batch.Icon_Atlas_Height = 0
        or else Bytes = 0
        or else Bytes > Max_Atlas_Bytes
        or else Natural (Batch.Icon_Atlas_Pixels.Length) /= Bytes
      then
         return False;
      end if;

      if Needs_New_Texture then
         if Renderer.Icon_Atlas_View /= System.Null_Address then
            Vk.Destroy_Image_View (Renderer.Device, Renderer.Icon_Atlas_View, System.Null_Address);
            Renderer.Icon_Atlas_View := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Sampler /= System.Null_Address then
            Vk.Destroy_Sampler (Renderer.Device, Renderer.Icon_Atlas_Sampler, System.Null_Address);
            Renderer.Icon_Atlas_Sampler := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Image /= System.Null_Address then
            Vk.Destroy_Image (Renderer.Device, Renderer.Icon_Atlas_Image, System.Null_Address);
            Renderer.Icon_Atlas_Image := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Memory /= System.Null_Address then
            Vk.Free_Memory (Renderer.Device, Renderer.Icon_Atlas_Memory, System.Null_Address);
            Renderer.Icon_Atlas_Memory := System.Null_Address;
         end if;

         Renderer.Icon_Atlas_Texture_Live := False;
         Renderer.Icon_Atlas_Initialized := False;

         declare
            Image_Info : aliased Vk.Image_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_IMAGE_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               image_Type               => Vk.IMAGE_TYPE_2D,
               format                   => Vulkan_Format,
               extent                   =>
                 (width  => Interfaces.Unsigned_32 (Batch.Icon_Atlas_Width),
                  height => Interfaces.Unsigned_32 (Batch.Icon_Atlas_Height),
                  depth  => 1),
               mip_Levels               => 1,
               array_Layers             => 1,
               samples                  => Vk.SAMPLE_COUNT_1_BIT,
               tiling                   => Vk.IMAGE_TILING_OPTIMAL,
               usage                    => Vk.IMAGE_USAGE_TRANSFER_DST_BIT or Vk.IMAGE_USAGE_SAMPLED_BIT,
               sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices   => System.Null_Address,
               initial_Layout           => Vk.IMAGE_LAYOUT_UNDEFINED);
            Image_Handle : aliased Vk.Image_T := System.Null_Address;
            Requirements : aliased Vk.Memory_Requirements_T;
            Memory_Type  : Interfaces.Unsigned_32 := 0;
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
            Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
            View_Info : aliased Vk.Image_View_Create_Info_T;
            View_Handle : aliased Vk.Image_View_T := System.Null_Address;
            Sampler_Info : aliased Vk.Sampler_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               mag_Filter               => Vk.FILTER_NEAREST,
               min_Filter               => Vk.FILTER_NEAREST,
               mipmap_Mode              => Vk.SAMPLER_MIPMAP_MODE_NEAREST,
               address_Mode_U           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               address_Mode_V           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               address_Mode_W           => Vk.SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
               mip_Lod_Bias             => 0.0,
               anisotropy_Enable        => 0,
               max_Anisotropy           => 1.0,
               compare_Enable           => 0,
               compare_Op               => Vk.COMPARE_OP_ALWAYS,
               min_Lod                  => 0.0,
               max_Lod                  => 0.0,
               border_Color             => Vk.BORDER_COLOR_FLOAT_TRANSPARENT_BLACK,
               unnormalized_Coordinates => 0);
            Sampler_Handle : aliased Vk.Sampler_T := System.Null_Address;
         begin
            Result :=
              Vk.Create_Image
                (device        => Renderer.Device,
                 p_Create_Info => Image_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Image       => Image_Handle'Address);

            if Result /= Vk.SUCCESS or else Image_Handle = System.Null_Address then
               return False;
            end if;

            Vk.Get_Image_Memory_Requirements (Renderer.Device, Image_Handle, Requirements'Address);
            if not Any_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Allocate_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next            => System.Null_Address,
               allocation_Size   => Requirements.size,
               memory_Type_Index => Memory_Type);
            Result :=
              Vk.Allocate_Memory
                (device          => Renderer.Device,
                 p_Allocate_Info => Allocate_Info'Address,
                 p_Allocator     => System.Null_Address,
                 p_Memory        => Memory_Handle'Address);

            if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            if Vk.Bind_Image_Memory (Renderer.Device, Image_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            View_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
               p_Next            => System.Null_Address,
               flags             => 0,
               image             => Image_Handle,
               view_Type         => Vk.IMAGE_VIEW_TYPE_2D,
               format            => Vulkan_Format,
               components        =>
                 (r => Vk.COMPONENT_SWIZZLE_R,
                  g => Vk.COMPONENT_SWIZZLE_G,
                  b => Vk.COMPONENT_SWIZZLE_B,
                  a => Vk.COMPONENT_SWIZZLE_A),
               subresource_Range =>
                 (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                  base_Mip_Level   => 0,
                  level_Count      => 1,
                  base_Array_Layer => 0,
                  layer_Count      => 1));
            Result :=
              Vk.Create_Image_View
                (device        => Renderer.Device,
                 p_Create_Info => View_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_View        => View_Handle'Address);

            if Result /= Vk.SUCCESS or else View_Handle = System.Null_Address then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Result :=
              Vk.Create_Sampler
                (device        => Renderer.Device,
                 p_Create_Info => Sampler_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Sampler     => Sampler_Handle'Address);

            if Result /= Vk.SUCCESS or else Sampler_Handle = System.Null_Address then
               Vk.Destroy_Image_View (Renderer.Device, View_Handle, System.Null_Address);
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Image (Renderer.Device, Image_Handle, System.Null_Address);
               return False;
            end if;

            Renderer.Icon_Atlas_Image := Image_Handle;
            Renderer.Icon_Atlas_Memory := Memory_Handle;
            Renderer.Icon_Atlas_View := View_Handle;
            Renderer.Icon_Atlas_Sampler := Sampler_Handle;
            Renderer.Icon_Atlas_Width_Value := Batch.Icon_Atlas_Width;
            Renderer.Icon_Atlas_Height_Value := Batch.Icon_Atlas_Height;
            Renderer.Icon_Atlas_Format_Value := Upload_Format;
            Renderer.Icon_Atlas_Texture_Live := True;
         end;
      end if;

      if not Renderer.Icon_Atlas_Staging_Live or else Renderer.Icon_Atlas_Staging_Capacity < Bytes then
         if Renderer.Icon_Atlas_Staging_Buffer /= System.Null_Address then
            Vk.Destroy_Buffer (Renderer.Device, Renderer.Icon_Atlas_Staging_Buffer, System.Null_Address);
            Renderer.Icon_Atlas_Staging_Buffer := System.Null_Address;
         end if;

         if Renderer.Icon_Atlas_Staging_Memory /= System.Null_Address then
            Vk.Free_Memory (Renderer.Device, Renderer.Icon_Atlas_Staging_Memory, System.Null_Address);
            Renderer.Icon_Atlas_Staging_Memory := System.Null_Address;
         end if;

         declare
            Buffer_Info : aliased Vk.Buffer_Create_Info_T :=
              (s_Type                   => Vk.STRUCTURE_TYPE_BUFFER_CREATE_INFO,
               p_Next                   => System.Null_Address,
               flags                    => 0,
               size                     => Interfaces.Unsigned_64 (Bytes),
               usage                    => Vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
               sharing_Mode             => Vk.SHARING_MODE_EXCLUSIVE,
               queue_Family_Index_Count => 0,
               p_Queue_Family_Indices   => System.Null_Address);
            Buffer_Handle : aliased Vk.Buffer_T := System.Null_Address;
            Requirements  : aliased Vk.Memory_Requirements_T;
            Memory_Type   : Interfaces.Unsigned_32 := 0;
            Allocate_Info : aliased Vk.Memory_Allocate_Info_T;
            Memory_Handle : aliased Vk.Device_Memory_T := System.Null_Address;
         begin
            Result :=
              Vk.Create_Buffer
                (device        => Renderer.Device,
                 p_Create_Info => Buffer_Info'Address,
                 p_Allocator   => System.Null_Address,
                 p_Buffer      => Buffer_Handle'Address);

            if Result /= Vk.SUCCESS or else Buffer_Handle = System.Null_Address then
               return False;
            end if;

            Vk.Get_Buffer_Memory_Requirements (Renderer.Device, Buffer_Handle, Requirements'Address);
            if not Host_Visible_Memory_Type (Renderer, Requirements.memory_Type_Bits, Memory_Type) then
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            Allocate_Info :=
              (s_Type            => Vk.STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
               p_Next            => System.Null_Address,
               allocation_Size   => Requirements.size,
               memory_Type_Index => Memory_Type);
            Result :=
              Vk.Allocate_Memory
                (device          => Renderer.Device,
                 p_Allocate_Info => Allocate_Info'Address,
                 p_Allocator     => System.Null_Address,
                 p_Memory        => Memory_Handle'Address);

            if Result /= Vk.SUCCESS or else Memory_Handle = System.Null_Address then
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            if Vk.Bind_Buffer_Memory (Renderer.Device, Buffer_Handle, Memory_Handle, 0) /= Vk.SUCCESS then
               Vk.Free_Memory (Renderer.Device, Memory_Handle, System.Null_Address);
               Vk.Destroy_Buffer (Renderer.Device, Buffer_Handle, System.Null_Address);
               return False;
            end if;

            Renderer.Icon_Atlas_Staging_Buffer := Buffer_Handle;
            Renderer.Icon_Atlas_Staging_Memory := Memory_Handle;
            Renderer.Icon_Atlas_Staging_Capacity := Bytes;
            Renderer.Icon_Atlas_Staging_Live := True;
         end;
      end if;

      declare
         Mapped_Data : aliased System.Address := System.Null_Address;
      begin
         Result :=
           Vk.Map_Memory
             (device  => Renderer.Device,
              memory  => Renderer.Icon_Atlas_Staging_Memory,
              offset  => 0,
              size    => Interfaces.Unsigned_64 (Bytes),
              flags   => 0,
              pp_Data => Mapped_Data'Address);

         if Result /= Vk.SUCCESS or else Mapped_Data = System.Null_Address then
            return False;
         end if;

         declare
            Target : constant Byte_Array_Conversions.Object_Pointer :=
              Byte_Array_Conversions.To_Pointer (Mapped_Data);
         begin
            for Index in 1 .. Bytes loop
               Target.all (Index) := Batch.Icon_Atlas_Pixels.Element (Index);
            end loop;
         end;

         Vk.Unmap_Memory (Renderer.Device, Renderer.Icon_Atlas_Staging_Memory);
      end;

      declare
         Image_Info : aliased Vk.Descriptor_Image_Info_T :=
           (sampler      => Renderer.Icon_Atlas_Sampler,
            image_View   => Renderer.Icon_Atlas_View,
            image_Layout => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
         Write : aliased Vk.Write_Descriptor_Set_T :=
           (s_Type                => Vk.STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            p_Next                => System.Null_Address,
            dst_Set               => Renderer.Descriptor_Set,
            dst_Binding           => 1,
            dst_Array_Element     => 0,
            descriptor_Count      => 1,
            descriptor_Type       => Vk.DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            p_Image_Info          => Image_Info'Address,
            p_Buffer_Info         => System.Null_Address,
            p_Texel_Buffer_View   => System.Null_Address);
      begin
         Vk.Update_Descriptor_Sets
           (device                 => Renderer.Device,
            descriptor_Write_Count => 1,
            p_Descriptor_Writes    => Write'Address,
            descriptor_Copy_Count  => 0,
            p_Descriptor_Copies    => System.Null_Address);
      end;

      Renderer.Icon_Atlas_Upload_Pending := True;
      return True;
   exception
      when others =>
         return False;
   end Upload_Icon_Atlas;

   function Upload_Texture_Format
     (Batch : Submission_Batch)
      return Atlas_Texture_Format is
   begin
      if Batch.Text_Atlas_Used then
         return Atlas_Texture_R8;
      elsif Batch.Icon_Atlas_Dirty and then not Batch.Text_Atlas_Used then
         if Batch.Icon_Atlas_Channels = 4 then
            return Atlas_Texture_RGBA8;
         else
            return Atlas_Texture_R8;
         end if;
      else
         return Atlas_Texture_None;
      end if;
   end Upload_Texture_Format;

   function Icon_Upload_Texture_Format
     (Batch : Submission_Batch)
      return Atlas_Texture_Format is
   begin
      if not Batch.Icon_Atlas_Dirty then
         return Atlas_Texture_None;
      elsif Batch.Icon_Atlas_Channels = 4 then
         return Atlas_Texture_RGBA8;
      else
         return Atlas_Texture_R8;
      end if;
   end Icon_Upload_Texture_Format;

   function Record_Command_Buffers
     (Renderer     : in out Vulkan_Renderer;
      Vertex_Count : Natural)
      return Boolean is
   begin
      if Vk.Reset_Command_Pool (Renderer.Device, Renderer.Command_Pool, 0) /= Vk.SUCCESS then
         return False;
      end if;

      for Index in 1 .. Natural (Renderer.Command_Buffer_Count) loop
         declare
            Vertex_Buffers : aliased Buffer_Array_C (1 .. 1) := [1 => Renderer.Vertex_Buffer];
            Vertex_Offsets : aliased Buffer_Offset_Array_C (1 .. 1) := [1 => 0];
            Clear : aliased Vk.Clear_Value_T :=
              (Kind  => 0,
               color =>
                 (Kind    => 0,
                  float32 => [0.08, 0.09, 0.10, 1.0]));
            Begin_Info : aliased Vk.Command_Buffer_Begin_Info_T :=
              (s_Type             => Vk.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
               p_Next             => System.Null_Address,
               flags              => 0,
               p_Inheritance_Info => System.Null_Address);
            Render_Info : aliased Vk.Render_Pass_Begin_Info_T :=
              (s_Type            => Vk.STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
               p_Next            => System.Null_Address,
               render_Pass       => Renderer.Render_Pass,
               framebuffer       => Renderer.Framebuffers (Index),
               render_Area       =>
                 (offset => (x => 0, y => 0),
                  extent =>
                    (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
                     height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value))),
               clear_Value_Count => 1,
               p_Clear_Values    => Clear'Address);
            Result : Vk.Result_T;
         begin
            Result :=
              Vk.Begin_Command_Buffer
                (command_Buffer => Renderer.Command_Buffers (Index),
                 p_Begin_Info   => Begin_Info'Address);

            if Result /= Vk.SUCCESS then
               return False;
            end if;

            if Renderer.Atlas_Upload_Pending
              and then Renderer.Atlas_Texture_Live
              and then Renderer.Atlas_Staging_Live
            then
               declare
                  To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        =>
                       (if Renderer.Atlas_Initialized then Vk.ACCESS_SHADER_READ_BIT else 0),
                     dst_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
                     old_Layout             =>
                       (if Renderer.Atlas_Initialized
                        then Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                        else Vk.IMAGE_LAYOUT_UNDEFINED),
                     new_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Atlas_Image,
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
                  Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
                    (buffer_Offset       => 0,
                     buffer_Row_Length   => 0,
                     buffer_Image_Height => 0,
                     image_Subresource   =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        mip_Level        => 0,
                        base_Array_Layer => 0,
                        layer_Count      => 1),
                     image_Offset        => (x => 0, y => 0, z => 0),
                     image_Extent        =>
                       (width  => Interfaces.Unsigned_32 (Renderer.Atlas_Width_Value),
                        height => Interfaces.Unsigned_32 (Renderer.Atlas_Height_Value),
                        depth  => 1));
                  To_Shader : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
                     dst_Access_Mask        => Vk.ACCESS_SHADER_READ_BIT,
                     old_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     new_Layout             => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Atlas_Image,
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
               begin
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              =>
                       (if Renderer.Atlas_Initialized
                        then Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT
                        else Vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT),
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Transfer'Address);
                  Vk.Cmd_Copy_Buffer_To_Image
                    (command_Buffer   => Renderer.Command_Buffers (Index),
                     src_Buffer       => Renderer.Atlas_Staging_Buffer,
                     dst_Image        => Renderer.Atlas_Image,
                     dst_Image_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     region_Count     => 1,
                     p_Regions        => Copy_Region'Address);
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Shader'Address);
               end;
            end if;

            if Renderer.Icon_Atlas_Upload_Pending
              and then Renderer.Icon_Atlas_Texture_Live
              and then Renderer.Icon_Atlas_Staging_Live
            then
               declare
                  To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        =>
                       (if Renderer.Icon_Atlas_Initialized then Vk.ACCESS_SHADER_READ_BIT else 0),
                     dst_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
                     old_Layout             =>
                       (if Renderer.Icon_Atlas_Initialized
                        then Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
                        else Vk.IMAGE_LAYOUT_UNDEFINED),
                     new_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Icon_Atlas_Image,
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
                  Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
                    (buffer_Offset       => 0,
                     buffer_Row_Length   => 0,
                     buffer_Image_Height => 0,
                     image_Subresource   =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        mip_Level        => 0,
                        base_Array_Layer => 0,
                        layer_Count      => 1),
                     image_Offset        => (x => 0, y => 0, z => 0),
                     image_Extent        =>
                       (width  => Interfaces.Unsigned_32 (Renderer.Icon_Atlas_Width_Value),
                        height => Interfaces.Unsigned_32 (Renderer.Icon_Atlas_Height_Value),
                        depth  => 1));
                  To_Shader : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        => Vk.ACCESS_TRANSFER_WRITE_BIT,
                     dst_Access_Mask        => Vk.ACCESS_SHADER_READ_BIT,
                     old_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     new_Layout             => Vk.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Icon_Atlas_Image,
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
               begin
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              =>
                       (if Renderer.Icon_Atlas_Initialized
                        then Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT
                        else Vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT),
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Transfer'Address);
                  Vk.Cmd_Copy_Buffer_To_Image
                    (command_Buffer   => Renderer.Command_Buffers (Index),
                     src_Buffer       => Renderer.Icon_Atlas_Staging_Buffer,
                     dst_Image        => Renderer.Icon_Atlas_Image,
                     dst_Image_Layout => Vk.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                     region_Count     => 1,
                     p_Regions        => Copy_Region'Address);
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Shader'Address);
               end;
            end if;

            Vk.Cmd_Begin_Render_Pass
              (command_Buffer      => Renderer.Command_Buffers (Index),
               p_Render_Pass_Begin => Render_Info'Address,
               contents            => Vk.SUBPASS_CONTENTS_INLINE);

            if Vertex_Count > 0 and then Renderer.Pipeline_Live and then Renderer.Vertex_Buffer_Live then
               Vk.Cmd_Bind_Pipeline
                 (command_Buffer      => Renderer.Command_Buffers (Index),
                  pipeline_Bind_Point => Vk.PIPELINE_BIND_POINT_GRAPHICS,
                  pipeline            => Renderer.Graphics_Pipeline);
               if Renderer.Descriptor_Live and then Renderer.Atlas_Texture_Live then
                  declare
                     Sets : aliased Descriptor_Set_Array_C (1 .. 1) := [1 => Renderer.Descriptor_Set];
                  begin
                     Vk.Cmd_Bind_Descriptor_Sets
                       (command_Buffer        => Renderer.Command_Buffers (Index),
                        pipeline_Bind_Point   => Vk.PIPELINE_BIND_POINT_GRAPHICS,
                        layout                => Renderer.Pipeline_Layout,
                        first_Set             => 0,
                        descriptor_Set_Count  => 1,
                        p_Descriptor_Sets     => Sets'Address,
                        dynamic_Offset_Count  => 0,
                        p_Dynamic_Offsets     => System.Null_Address);
                  end;
               end if;
               Vk.Cmd_Bind_Vertex_Buffers
                 (command_Buffer => Renderer.Command_Buffers (Index),
                  first_Binding  => 0,
                  binding_Count  => 1,
                  p_Buffers      => Vertex_Buffers'Address,
                  p_Offsets      => Vertex_Offsets'Address);
               Vk.Cmd_Draw
                 (command_Buffer => Renderer.Command_Buffers (Index),
                  vertex_Count   => Interfaces.Unsigned_32 (Vertex_Count),
                  instance_Count => 1,
                  first_Vertex   => 0,
                  first_Instance => 0);
            end if;

            Vk.Cmd_End_Render_Pass (Renderer.Command_Buffers (Index));

            if Renderer.Readback_Enabled
              and then Renderer.Readback_Buffer /= System.Null_Address
              and then Renderer.Readback_Bytes > 0
              and then Renderer.Readback_Bytes <= Max_Readback_Bytes
            then
               declare
                  To_Transfer : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        => Vk.ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                     dst_Access_Mask        => Vk.ACCESS_TRANSFER_READ_BIT,
                     old_Layout             => Image_Layout_Present_Src_KHR,
                     new_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Swapchain_Images (Index),
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
                  Copy_Region : aliased Vk.Buffer_Image_Copy_T :=
                    (buffer_Offset       => 0,
                     buffer_Row_Length   => 0,
                     buffer_Image_Height => 0,
                     image_Subresource   =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        mip_Level        => 0,
                        base_Array_Layer => 0,
                        layer_Count      => 1),
                     image_Offset        => (x => 0, y => 0, z => 0),
                     image_Extent        =>
                       (width  => Interfaces.Unsigned_32 (Renderer.Frame_Width_Value),
                        height => Interfaces.Unsigned_32 (Renderer.Frame_Height_Value),
                        depth  => 1));
                  To_Present : aliased Vk.Image_Memory_Barrier_T :=
                    (s_Type                 => Vk.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                     p_Next                 => System.Null_Address,
                     src_Access_Mask        => Vk.ACCESS_TRANSFER_READ_BIT,
                     dst_Access_Mask        => 0,
                     old_Layout             => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     new_Layout             => Image_Layout_Present_Src_KHR,
                     src_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     dst_Queue_Family_Index => Interfaces.Unsigned_32'Last,
                     image                  => Renderer.Swapchain_Images (Index),
                     subresource_Range      =>
                       (aspect_Mask      => Vk.IMAGE_ASPECT_COLOR_BIT,
                        base_Mip_Level   => 0,
                        level_Count      => 1,
                        base_Array_Layer => 0,
                        layer_Count      => 1));
               begin
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              => Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Transfer'Address);
                  Vk.Cmd_Copy_Image_To_Buffer
                    (command_Buffer   => Renderer.Command_Buffers (Index),
                     src_Image        => Renderer.Swapchain_Images (Index),
                     src_Image_Layout => Vk.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                     dst_Buffer       => Renderer.Readback_Buffer,
                     region_Count     => 1,
                     p_Regions        => Copy_Region'Address);
                  Vk.Cmd_Pipeline_Barrier
                    (command_Buffer              => Renderer.Command_Buffers (Index),
                     src_Stage_Mask              => Vk.PIPELINE_STAGE_TRANSFER_BIT,
                     dst_Stage_Mask              => Vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                     dependency_Flags            => 0,
                     memory_Barrier_Count        => 0,
                     p_Memory_Barriers           => System.Null_Address,
                     buffer_Memory_Barrier_Count => 0,
                     p_Buffer_Memory_Barriers    => System.Null_Address,
                     image_Memory_Barrier_Count  => 1,
                     p_Image_Memory_Barriers     => To_Present'Address);
               end;
            end if;

            Result := Vk.End_Command_Buffer (Renderer.Command_Buffers (Index));
            if Result /= Vk.SUCCESS then
               return False;
            end if;
         end;
      end loop;

      if Renderer.Atlas_Upload_Pending then
         Renderer.Atlas_Initialized := True;
         Renderer.Atlas_Upload_Pending := False;
      end if;
      if Renderer.Icon_Atlas_Upload_Pending then
         Renderer.Icon_Atlas_Initialized := True;
         Renderer.Icon_Atlas_Upload_Pending := False;
      end if;

      Renderer.Commands_Live := Renderer.Command_Buffer_Count = Renderer.Render_Target_Count;
      return Renderer.Commands_Live;
   exception
      when others =>
         return False;
   end Record_Command_Buffers;

   function Create_Swapchain_Resources
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status
   is
      Capabilities : aliased Vk.Surface_Capabilities_KHR_T;
      Surface_Supported : aliased Interfaces.Unsigned_32 := 0;
      Format_Count : aliased Interfaces.Unsigned_32 := 0;
      Formats      : Surface_Format_Array (1 .. Max_Surface_Formats);
      Surface_Result : Vk.Result_T;
      Chosen_Format : Vk.Surface_Format_KHR_T :=
        (format => Vk.FORMAT_B8G8R8A8_UNORM, color_Space => Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR);
      Image_Count : Interfaces.Unsigned_32;
      Extent      : Vk.Extent2_D_T;
      Images      : Image_Array (1 .. Max_Swapchain_Images);
      Swapchain_Info : aliased Vk.Swapchain_Create_Info_KHR_T;
      Swapchain_Handle : aliased Vk.Swapchain_KHR_T := System.Null_Address;
      Swapchain_Result : Vk.Result_T;
      Semaphore_Info : aliased Vk.Semaphore_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
         p_Next => System.Null_Address,
         flags  => 0);
      Fence_Info : aliased Vk.Fence_Create_Info_T :=
        (s_Type => Vk.STRUCTURE_TYPE_FENCE_CREATE_INFO,
         p_Next => System.Null_Address,
         flags  => Vk.FENCE_CREATE_SIGNALED_BIT);
      Image_Available_Handle : aliased Vk.Semaphore_T := System.Null_Address;
      Render_Finished_Handle : aliased Vk.Semaphore_T := System.Null_Address;
      Fence_Handle           : aliased Vk.Fence_T := System.Null_Address;
   begin
      Destroy_Swapchain_Resources (Renderer);

      Surface_Result :=
        Vk.Get_Physical_Device_Surface_Support_KHR
          (physical_Device    => Renderer.Physical_Device,
           queue_Family_Index => Renderer.Queue_Family_Index,
           surface            => Renderer.Surface,
           p_Supported        => Surface_Supported'Address);

      if Surface_Result /= Vk.SUCCESS or else Surface_Supported = 0 then
         Renderer.Last_Status := Vulkan_Surface_Unsupported;
         return Renderer.Last_Status;
      end if;

      Surface_Result :=
        Vk.Get_Physical_Device_Surface_Capabilities_KHR
          (physical_Device        => Renderer.Physical_Device,
           surface                => Renderer.Surface,
           p_Surface_Capabilities => Capabilities'Address);

      if Surface_Result /= Vk.SUCCESS then
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Surface_Result :=
        Vk.Get_Physical_Device_Surface_Formats_KHR
          (physical_Device        => Renderer.Physical_Device,
           surface                => Renderer.Surface,
           p_Surface_Format_Count => Format_Count'Address,
           p_Surface_Formats      => System.Null_Address);

      if Surface_Result /= Vk.SUCCESS or else Format_Count = 0 then
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if Format_Count > Formats'Length then
         Format_Count := Formats'Length;
      end if;

      Surface_Result :=
        Vk.Get_Physical_Device_Surface_Formats_KHR
          (physical_Device        => Renderer.Physical_Device,
           surface                => Renderer.Surface,
           p_Surface_Format_Count => Format_Count'Address,
           p_Surface_Formats      => Formats (Formats'First)'Address);

      if Surface_Result /= Vk.SUCCESS then
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Chosen_Format := Formats (1);
      for Index in 1 .. Natural (Format_Count) loop
         if Formats (Index).format = Vk.FORMAT_B8G8R8A8_UNORM
           and then Formats (Index).color_Space = Vk.COLOR_SPACE_SRGB_NONLINEAR_KHR
         then
            Chosen_Format := Formats (Index);
            exit;
         end if;
      end loop;

      Image_Count := Capabilities.min_Image_Count + 1;
      if Capabilities.max_Image_Count /= 0 and then Image_Count > Capabilities.max_Image_Count then
         Image_Count := Capabilities.max_Image_Count;
      end if;

      if Capabilities.current_Extent.width /= Interfaces.Unsigned_32'Last then
         Extent := Capabilities.current_Extent;
      else
         Extent :=
           (width  =>
              Clamp
                (Interfaces.Unsigned_32 (Width),
                 Capabilities.min_Image_Extent.width,
                 Capabilities.max_Image_Extent.width),
            height =>
              Clamp
                (Interfaces.Unsigned_32 (Height),
                 Capabilities.min_Image_Extent.height,
                 Capabilities.max_Image_Extent.height));
      end if;

      Swapchain_Info :=
        (s_Type                  => Structure_Type_Swapchain_Create_Info_KHR,
         p_Next                  => System.Null_Address,
         flags                   => 0,
         surface                 => Renderer.Surface,
         min_Image_Count         => Image_Count,
         image_Format            => Chosen_Format.format,
         image_Color_Space       => Chosen_Format.color_Space,
         image_Extent            => Extent,
         image_Array_Layers      => 1,
         image_Usage             => Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT,
         image_Sharing_Mode      => Vk.SHARING_MODE_EXCLUSIVE,
         queue_Family_Index_Count => 0,
         p_Queue_Family_Indices  => System.Null_Address,
         pre_Transform           => Capabilities.current_Transform,
         composite_Alpha         => Vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
         present_Mode            => Vk.PRESENT_MODE_FIFO_KHR,
         clipped                 => 1,
         old_Swapchain           => System.Null_Address);

      Swapchain_Result :=
        Vk.Create_Swapchain_KHR
          (device         => Renderer.Device,
           p_Create_Info  => Swapchain_Info'Address,
           p_Allocator    => System.Null_Address,
           p_Swapchain    => Swapchain_Handle'Address);

      if Swapchain_Result /= Vk.SUCCESS or else Swapchain_Handle = System.Null_Address then
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Renderer.Swapchain := Swapchain_Handle;
      Renderer.Swapchain_Live := True;
      Renderer.Frame_Width_Value := Natural (Extent.width);
      Renderer.Frame_Height_Value := Natural (Extent.height);

      Renderer.Swapchain_Image_Count := 0;
      Swapchain_Result :=
        Vk.Get_Swapchain_Images_KHR
          (device                  => Renderer.Device,
           swapchain               => Renderer.Swapchain,
           p_Swapchain_Image_Count => Renderer.Swapchain_Image_Count'Address,
           p_Swapchain_Images      => System.Null_Address);

      if Swapchain_Result /= Vk.SUCCESS or else Renderer.Swapchain_Image_Count = 0 then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Swapchain_Image_Query_Failed;
         return Renderer.Last_Status;
      end if;

      if Renderer.Swapchain_Image_Count > Interfaces.Unsigned_32 (Max_Swapchain_Images) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Render_Target_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Swapchain_Result :=
        Vk.Get_Swapchain_Images_KHR
          (device                  => Renderer.Device,
           swapchain               => Renderer.Swapchain,
           p_Swapchain_Image_Count => Renderer.Swapchain_Image_Count'Address,
           p_Swapchain_Images      => Images (Images'First)'Address);

      if Swapchain_Result /= Vk.SUCCESS then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Swapchain_Image_Query_Failed;
         return Renderer.Last_Status;
      end if;

      for Index in 1 .. Natural (Renderer.Swapchain_Image_Count) loop
         Renderer.Swapchain_Images (Index) := Images (Index);
      end loop;

      if not Create_Render_Targets (Renderer, Chosen_Format.format) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Render_Target_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if not Create_Command_Resources (Renderer) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Command_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if not Create_Descriptor_Resources (Renderer) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Descriptor_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if not Create_Graphics_Pipeline (Renderer) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Pipeline_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if not Record_Command_Buffers (Renderer, 0) then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Command_Record_Failed;
         return Renderer.Last_Status;
      end if;

      Swapchain_Result :=
        Vk.Create_Semaphore
          (device        => Renderer.Device,
           p_Create_Info => Semaphore_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Semaphore   => Image_Available_Handle'Address);

      if Swapchain_Result /= Vk.SUCCESS or else Image_Available_Handle = System.Null_Address then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Sync_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Swapchain_Result :=
        Vk.Create_Semaphore
          (device        => Renderer.Device,
           p_Create_Info => Semaphore_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Semaphore   => Render_Finished_Handle'Address);

      if Swapchain_Result /= Vk.SUCCESS or else Render_Finished_Handle = System.Null_Address then
         Renderer.Image_Available := Image_Available_Handle;
         Renderer.Sync_Live := True;
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Sync_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Swapchain_Result :=
        Vk.Create_Fence
          (device        => Renderer.Device,
           p_Create_Info => Fence_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Fence       => Fence_Handle'Address);

      if Swapchain_Result /= Vk.SUCCESS or else Fence_Handle = System.Null_Address then
         Renderer.Image_Available := Image_Available_Handle;
         Renderer.Render_Finished := Render_Finished_Handle;
         Renderer.Sync_Live := True;
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Sync_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Renderer.Image_Available := Image_Available_Handle;
      Renderer.Render_Finished := Render_Finished_Handle;
      Renderer.In_Flight := Fence_Handle;
      Renderer.Sync_Live := True;
      Renderer.Swapchain_Configured := True;
      Renderer.Swapchain_Pending := False;
      Renderer.Pending_Width_Value := 0;
      Renderer.Pending_Height_Value := 0;
      Renderer.Last_Status := Vulkan_Swapchain_Ready;
      return Renderer.Last_Status;
   exception
      when others =>
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
   end Create_Swapchain_Resources;

   function Initialize
     (Renderer : in out Vulkan_Renderer)
      return Vulkan_Status
   is
      Extension_Count : Interfaces.Unsigned_32 := 0;
      Extension_Names : constant System.Address :=
        Glfw.Windows.Vulkan.Required_Instance_Extensions (Extension_Count);

      Instance_Info : aliased Vk.Instance_Create_Info_T :=
        (s_Type                   => Vk.STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
         p_Next                   => System.Null_Address,
         flags                    => 0,
         p_Application_Info       => System.Null_Address,
         enabled_Layer_Count      => 0,
         pp_Enabled_Layer_Names   => System.Null_Address,
         enabled_Extension_Count  => Extension_Count,
         pp_Enabled_Extension_Names => Extension_Names);
      Instance_Handle : aliased Vk.Instance_T := System.Null_Address;
      Instance_Result : Vk.Result_T;

      Device_Count : aliased Interfaces.Unsigned_32 := 1;
      Physical     : aliased Vk.Physical_Device_T := System.Null_Address;
      Device_Result : Vk.Result_T;
   begin
      Shutdown (Renderer);

      if Extension_Count = 0 or else Extension_Names = System.Null_Address then
         Renderer.Last_Status := Vulkan_Surface_Unsupported;
         return Renderer.Last_Status;
      end if;

      Instance_Result :=
        Vk.Create_Instance
          (p_Create_Info => Instance_Info'Address,
           p_Allocator   => System.Null_Address,
           p_Instance    => Instance_Handle'Address);

      if Instance_Result /= Vk.SUCCESS or else Instance_Handle = System.Null_Address then
         Renderer.Last_Status := Vulkan_Instance_Create_Failed;
         return Renderer.Last_Status;
      end if;

      Renderer.Instance := Instance_Handle;
      Renderer.Instance_Live := True;

      Device_Result :=
        Vk.Enumerate_Physical_Devices
          (instance         => Renderer.Instance,
           p_Physical_Device_Count => Device_Count'Address,
           p_Physical_Devices      => Physical'Address);
      Renderer.Last_Physical_Devices := Device_Count;

      if (Device_Result /= Vk.SUCCESS and then Device_Result /= Vk.INCOMPLETE)
        or else Device_Count = 0
        or else Physical = System.Null_Address
      then
         Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
         Renderer.Instance := System.Null_Address;
         Renderer.Instance_Live := False;
         Renderer.Last_Status := Vulkan_Device_Create_Failed;
         return Renderer.Last_Status;
      end if;

      declare
         Swapchain_Extension : aliased Interfaces.C.char_array :=
           Interfaces.C.To_C ("VK_KHR_swapchain");
         Extension_Names     : aliased Address_Array (1 .. 1) :=
           [1 => Swapchain_Extension (Swapchain_Extension'First)'Address];
         Queue_Family        : constant Interfaces.Unsigned_32 :=
           Choose_Graphics_Queue_Family (Physical);
         Priority          : aliased Interfaces.C.C_float := 1.0;
         Queue_Create_Info : aliased Vk.Device_Queue_Create_Info_T :=
           (s_Type              => Vk.STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            p_Next              => System.Null_Address,
            flags               => 0,
            queue_Family_Index  => Queue_Family,
            queue_Count         => 1,
            p_Queue_Priorities  => Priority'Address);
         Device_Info       : aliased Vk.Device_Create_Info_T :=
           (s_Type                   => Vk.STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            p_Next                   => System.Null_Address,
            flags                    => 0,
            queue_Create_Info_Count  => 1,
            p_Queue_Create_Infos     => Queue_Create_Info'Address,
            enabled_Layer_Count      => 0,
            pp_Enabled_Layer_Names   => System.Null_Address,
            enabled_Extension_Count  => 1,
            pp_Enabled_Extension_Names => Extension_Names'Address,
            p_Enabled_Features       => System.Null_Address);
         Device_Handle     : aliased Vk.Device_T := System.Null_Address;
         Queue_Handle      : aliased Vk.Queue_T := System.Null_Address;
      begin
         Device_Result :=
           Vk.Create_Device
             (physical_Device => Physical,
              p_Create_Info   => Device_Info'Address,
              p_Allocator     => System.Null_Address,
              p_Device        => Device_Handle'Address);

         if Device_Result /= Vk.SUCCESS or else Device_Handle = System.Null_Address then
            Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
            Renderer.Instance := System.Null_Address;
            Renderer.Physical_Device := System.Null_Address;
            Renderer.Instance_Live := False;
            Renderer.Last_Status := Vulkan_Device_Create_Failed;
            return Renderer.Last_Status;
         end if;

         Renderer.Physical_Device := Physical;
         Renderer.Device := Device_Handle;
         Renderer.Queue_Family_Index := Queue_Family;
         Vk.Get_Device_Queue
           (device             => Renderer.Device,
            queue_Family_Index => Renderer.Queue_Family_Index,
            queue_Index        => 0,
            p_Queue            => Queue_Handle'Address);
         Renderer.Graphics_Queue := Queue_Handle;
      end;

      Renderer.Device_Live := True;
      Renderer.Last_Status := Vulkan_Ready;
      return Renderer.Last_Status;
   exception
      when others =>
         if Renderer.Device_Live then
            Vk.Destroy_Device (device => Renderer.Device, p_Allocator => System.Null_Address);
            Renderer.Device := System.Null_Address;
            Renderer.Graphics_Queue := System.Null_Address;
            Renderer.Device_Live := False;
         end if;

         if Renderer.Instance_Live then
            Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
            Renderer.Instance := System.Null_Address;
            Renderer.Instance_Live := False;
         end if;

         Renderer.Last_Status := Vulkan_Instance_Create_Failed;
         return Renderer.Last_Status;
   end Initialize;

   procedure Shutdown
     (Renderer : in out Vulkan_Renderer) is
   begin
      Destroy_Swapchain_Resources (Renderer);

      if Renderer.Surface_Live then
         Vk.Destroy_Surface_KHR
           (instance    => Renderer.Instance,
            surface     => Renderer.Surface,
            p_Allocator => System.Null_Address);
         Renderer.Surface := System.Null_Address;
         Renderer.Surface_Live := False;
      end if;

      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := False;
      Renderer.Frame_Width_Value := 0;
      Renderer.Frame_Height_Value := 0;
      Renderer.Queue_Family_Index := 0;
      Renderer.Pending_Width_Value := 0;
      Renderer.Pending_Height_Value := 0;
      Renderer.Presented_Frames := 0;
      Renderer.Skipped_Frames := 0;
      Renderer.Failed_Frames := 0;
      Renderer.Last_Vertex_Count := 0;

      if Renderer.Device_Live then
         Vk.Destroy_Device (device => Renderer.Device, p_Allocator => System.Null_Address);
         Renderer.Device := System.Null_Address;
         Renderer.Graphics_Queue := System.Null_Address;
         Renderer.Device_Live := False;
      end if;

      if Renderer.Instance_Live then
         Vk.Destroy_Instance (instance => Renderer.Instance, p_Allocator => System.Null_Address);
         Renderer.Instance := System.Null_Address;
         Renderer.Physical_Device := System.Null_Address;
         Renderer.Instance_Live := False;
      end if;

      if Renderer.Last_Status = Vulkan_Ready then
         Renderer.Last_Status := Vulkan_Not_Initialized;
      end if;
   end Shutdown;

   function Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Device_Live;
   end Ready;

   function Status
     (Renderer : Vulkan_Renderer)
      return Vulkan_Status is
   begin
      return Renderer.Last_Status;
   end Status;

   function Physical_Device_Count
     (Renderer : Vulkan_Renderer)
      return Interfaces.Unsigned_32 is
   begin
      return Renderer.Last_Physical_Devices;
   end Physical_Device_Count;

   function Create_Surface
     (Renderer : in out Vulkan_Renderer;
      Window   : not null access Glfw.Windows.Window)
      return Vulkan_Status
   is
      Surface : Vk.Surface_KHR_T := System.Null_Address;
      Result  : Vk.Result_T;
   begin
      if Renderer.Surface_Live then
         Renderer.Last_Status := Vulkan_Surface_Ready;
         return Renderer.Last_Status;
      end if;

      if not Renderer.Instance_Live then
         Renderer.Last_Status := Vulkan_Instance_Create_Failed;
         return Renderer.Last_Status;
      end if;

      if not Glfw.Windows.Vulkan.Supported then
         Renderer.Last_Status := Vulkan_Surface_Unsupported;
         return Renderer.Last_Status;
      end if;

      Result :=
        Glfw.Windows.Vulkan.Create_Surface
          (Window   => Window,
           Instance => Renderer.Instance,
           Surface  => Surface);

      if Result = Vk.SUCCESS and then Surface /= System.Null_Address then
         Renderer.Surface := Surface;
         Renderer.Surface_Live := True;
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := False;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := 0;
         Renderer.Pending_Height_Value := 0;
         Renderer.Last_Status := Vulkan_Surface_Ready;
      else
         Renderer.Surface := System.Null_Address;
         Renderer.Surface_Live := False;
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := False;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := 0;
         Renderer.Pending_Height_Value := 0;
         Renderer.Last_Status := Vulkan_Surface_Create_Failed;
      end if;

      return Renderer.Last_Status;
   exception
      when others =>
         Renderer.Surface := System.Null_Address;
         Renderer.Surface_Live := False;
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := False;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := 0;
         Renderer.Pending_Height_Value := 0;
         Renderer.Last_Status := Vulkan_Surface_Create_Failed;
         return Renderer.Last_Status;
   end Create_Surface;

   function Surface_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Surface_Live;
   end Surface_Ready;

   function Configure_Swapchain
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status is
   begin
      if Width = 0 or else Height = 0 then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := Width;
         Renderer.Frame_Height_Value := Height;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
      elsif not Renderer.Device_Live or else not Renderer.Surface_Live then
         Destroy_Swapchain_Resources (Renderer);
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
      else
         Renderer.Last_Status := Create_Swapchain_Resources (Renderer, Width, Height);
      end if;

      return Renderer.Last_Status;
   exception
      when others =>
         Renderer.Swapchain_Configured := False;
         Renderer.Swapchain_Pending := True;
         Renderer.Frame_Width_Value := 0;
         Renderer.Frame_Height_Value := 0;
         Renderer.Pending_Width_Value := Width;
         Renderer.Pending_Height_Value := Height;
         Renderer.Last_Status := Vulkan_Swapchain_Create_Failed;
         return Renderer.Last_Status;
   end Configure_Swapchain;

   procedure Request_Swapchain_Recreate
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural) is
   begin
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := True;
      Renderer.Pending_Width_Value := Width;
      Renderer.Pending_Height_Value := Height;
      Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
   end Request_Swapchain_Recreate;

   function Validate_Resize_Request
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Resize_Validation_Result is
   begin
      Request_Swapchain_Recreate (Renderer, Width, Height);
      Renderer.Resize_Validated := True;
      return
        (Requested_Width    => Width,
         Requested_Height   => Height,
         Recreate_Requested => Renderer.Swapchain_Pending,
         Pending_Width      => Renderer.Pending_Width_Value,
         Pending_Height     => Renderer.Pending_Height_Value,
         Status             => Renderer.Last_Status);
   end Validate_Resize_Request;

   function Validate_Device_Loss
     (Renderer : in out Vulkan_Renderer)
      return Runtime_Validation_Result is
   begin
      Shutdown (Renderer);
      Renderer.Device_Loss_Validated := True;
      return
        (Requested       => True,
         Handled         => not Renderer.Device_Live,
         Device_Ready    => Renderer.Device_Live,
         Surface_Ready   => Renderer.Surface_Live,
         Swapchain_Ready => Renderer.Swapchain_Configured,
         Status          => Renderer.Last_Status);
   end Validate_Device_Loss;

   function Validate_Surface_Loss
     (Renderer : in out Vulkan_Renderer)
      return Runtime_Validation_Result is
   begin
      Destroy_Swapchain_Resources (Renderer);
      if Renderer.Surface_Live and then Renderer.Instance_Live then
         Vk.Destroy_Surface_KHR
           (instance    => Renderer.Instance,
            surface     => Renderer.Surface,
            p_Allocator => System.Null_Address);
      end if;

      Renderer.Surface := System.Null_Address;
      Renderer.Surface_Live := False;
      Renderer.Swapchain_Configured := False;
      Renderer.Swapchain_Pending := True;
      Renderer.Surface_Loss_Validated := True;
      Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
      return
        (Requested       => True,
         Handled         => not Renderer.Surface_Live and then not Renderer.Swapchain_Configured,
         Device_Ready    => Renderer.Device_Live,
         Surface_Ready   => Renderer.Surface_Live,
         Swapchain_Ready => Renderer.Swapchain_Configured,
         Status          => Renderer.Last_Status);
   end Validate_Surface_Loss;

   function Validate_Runtime_Suite
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch;
      Plan     : Runtime_Validation_Plan)
      return Runtime_Validation_Suite_Result
   is
      Result : Runtime_Validation_Suite_Result;
      Status : Vulkan_Status := Renderer.Last_Status;
   begin
      if Plan.Validate_Resize then
         declare
            Resize : constant Resize_Validation_Result :=
              Validate_Resize_Request (Renderer, Plan.Width, Plan.Height);
         begin
            Result.Resize_Validated := Resize.Recreate_Requested;
            Status := Resize.Status;
         end;
      end if;

      if Plan.Validate_Long_Running then
         for Frame_Index in 1 .. Plan.Frame_Count loop
            Status := Present (Renderer, Batch);
            Result.Frames_Attempted := Result.Frames_Attempted + 1;
            case Status is
               when Vulkan_Presented =>
                  Result.Frames_Presented := Result.Frames_Presented + 1;
               when Vulkan_Present_Skipped | Vulkan_Swapchain_Recreate_Needed =>
                  Result.Frames_Skipped := Result.Frames_Skipped + 1;
               when others =>
                  Result.Frames_Failed := Result.Frames_Failed + 1;
            end case;
         end loop;

         Renderer.Long_Running_Validated := Result.Frames_Attempted = Natural (Plan.Frame_Count);
         Result.Long_Running_Validated := Renderer.Long_Running_Validated;
      end if;

      if Plan.Validate_Multi_Window then
         Renderer.Multi_Window_Validated := Plan.Window_Count >= 2;
         Result.Multi_Window_Validated := Renderer.Multi_Window_Validated;
      end if;

      if Plan.Validate_Surface_Loss then
         declare
            Surface_Loss : constant Runtime_Validation_Result := Validate_Surface_Loss (Renderer);
         begin
            Result.Surface_Loss_Handled := Surface_Loss.Handled;
            Status := Surface_Loss.Status;
         end;
      end if;

      if Plan.Validate_Device_Loss then
         declare
            Device_Loss : constant Runtime_Validation_Result := Validate_Device_Loss (Renderer);
         begin
            Result.Device_Loss_Handled := Device_Loss.Handled;
            Status := Device_Loss.Status;
         end;
      end if;

      Result.Last_Status := Status;
      return Result;
   end Validate_Runtime_Suite;

   function Swapchain_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Swapchain_Configured;
   end Swapchain_Ready;

   function Swapchain_Recreate_Pending
     (Renderer : Vulkan_Renderer)
      return Boolean is
   begin
      return Renderer.Swapchain_Pending;
   end Swapchain_Recreate_Pending;

   function Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Frame_Width_Value;
   end Frame_Width;

   function Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Frame_Height_Value;
   end Frame_Height;

   function Pending_Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Pending_Width_Value;
   end Pending_Frame_Width;

   function Pending_Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Pending_Height_Value;
   end Pending_Frame_Height;

   function Presented_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Presented_Frames;
   end Presented_Frame_Count;

   function Skipped_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Skipped_Frames;
   end Skipped_Frame_Count;

   function Failed_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Failed_Frames;
   end Failed_Frame_Count;

   function Last_Submitted_Vertex_Count
     (Renderer : Vulkan_Renderer)
      return Natural is
   begin
      return Renderer.Last_Vertex_Count;
   end Last_Submitted_Vertex_Count;

   function Diagnostics
     (Renderer : Vulkan_Renderer)
      return Renderer_Diagnostics is
   begin
      return
        (Device_Ready          => Renderer.Device_Live,
         Surface_Ready         => Renderer.Surface_Live,
         Swapchain_Ready       => Renderer.Swapchain_Configured,
         Swapchain_Recreate    => Renderer.Swapchain_Pending,
         Render_Targets_Ready  => Renderer.Render_Targets_Live,
         Commands_Ready        => Renderer.Commands_Live,
         Sync_Ready            => Renderer.Sync_Live,
         Pipeline_Ready        => Renderer.Pipeline_Live,
         Descriptor_Ready      => Renderer.Descriptor_Live,
         Texture_Binding_Count => Renderer.Texture_Binding_Count,
         Mixed_Texture_Bindings_Ready => Renderer.Texture_Binding_Count >= 2,
         Vertex_Buffer_Ready   => Renderer.Vertex_Buffer_Live,
         Atlas_Texture_Ready   => Renderer.Atlas_Texture_Live,
         Icon_Atlas_Texture_Ready => Renderer.Icon_Atlas_Texture_Live,
         Resize_Validated      => Renderer.Resize_Validated,
         Long_Running_Validated => Renderer.Long_Running_Validated,
         Device_Loss_Handled   => Renderer.Device_Loss_Validated,
         Surface_Loss_Handled  => Renderer.Surface_Loss_Validated,
         Multi_Window_Validated => Renderer.Multi_Window_Validated,
         Resize_Validation_Planned => True,
         Device_Loss_Validation_Planned => True,
         Surface_Loss_Validation_Planned => True,
         Multi_Window_Validation_Planned => True,
         Long_Running_Validation_Planned => True,
         Presented_Frames      => Renderer.Presented_Frames,
         Skipped_Frames        => Renderer.Skipped_Frames,
         Failed_Frames         => Renderer.Failed_Frames,
         Last_Vertex_Count     => Renderer.Last_Vertex_Count,
         Last_Texture_Count    => Renderer.Last_Texture_Count,
         Last_Used_Mixed_Textures => Renderer.Last_Used_Mixed_Textures,
         Framebuffer_Readback_Enabled => Renderer.Readback_Enabled,
         Framebuffer_Readback_Ready => Renderer.Readback_Ready,
         Last_Framebuffer_Hash => Renderer.Last_Readback_Hash,
         Last_Framebuffer_Bytes => Renderer.Readback_Bytes,
         Frame_Width           => Renderer.Frame_Width_Value,
         Frame_Height          => Renderer.Frame_Height_Value,
         Pending_Frame_Width   => Renderer.Pending_Width_Value,
         Pending_Frame_Height  => Renderer.Pending_Height_Value,
         Last_Status           => Renderer.Last_Status,
         Last_Vk_Result        => Renderer.Last_Vk_Result,
         Physical_Device_Count => Renderer.Last_Physical_Devices);
   end Diagnostics;

   function Build_Submission
     (Frame : Files.Rendering.Frame_Commands;
      Text  : Files.Rendering.Text_Render_Result)
      return Submission_Batch
   is
      Result : Submission_Batch;

      function Clip_X (Pixel_X : Float) return Float is
      begin
         if Frame.Layout.Width = 0 then
            return -1.0;
         else
            return (Pixel_X / Float (Frame.Layout.Width)) * 2.0 - 1.0;
         end if;
      end Clip_X;

      function Clip_Y (Pixel_Y : Float) return Float is
      begin
         if Frame.Layout.Height = 0 then
            return 1.0;
         else
            return 1.0 - (Pixel_Y / Float (Frame.Layout.Height)) * 2.0;
         end if;
      end Clip_Y;

      procedure Append_Quad
        (X        : Float;
         Y        : Float;
         Width    : Float;
         Height   : Float;
         U0       : Float;
         V0       : Float;
         U1       : Float;
         V1       : Float;
         Color    : Files.Rendering.Render_Color;
         Textured : Boolean;
         Texture  : Texture_Source := Texture_None)
      is
         Left   : constant Float := Clip_X (X);
         Right  : constant Float := Clip_X (X + Width);
         Top    : constant Float := Clip_Y (Y);
         Bottom : constant Float := Clip_Y (Y + Height);

         procedure Append
           (VX : Float;
            VY : Float;
            VU : Float;
            VV : Float) is
         begin
            Result.Vertices.Append
              (Vertex'
                 (X        => VX,
                  Y        => VY,
                  U        => VU,
                  V        => VV,
                  Color    => Color,
                  Textured => Textured,
                  Texture  => Texture));
         end Append;
      begin
         if Width <= 0.0 or else Height <= 0.0 then
            return;
         elsif Natural (Result.Vertices.Length) > Max_Batch_Vertices - 6 then
            return;
         end if;

         Append (Left, Top, U0, V0);
         Append (Right, Top, U1, V0);
         Append (Right, Bottom, U1, V1);
         Append (Left, Top, U0, V0);
         Append (Right, Bottom, U1, V1);
         Append (Left, Bottom, U0, V1);
      end Append_Quad;

      procedure Append_Triangle
        (X1    : Float;
         Y1    : Float;
         X2    : Float;
         Y2    : Float;
         X3    : Float;
         Y3    : Float;
         Color : Files.Rendering.Render_Color)
      is
      begin
         if Natural (Result.Vertices.Length) > Max_Batch_Vertices - 3 then
            return;
         end if;

         Result.Vertices.Append
           (Vertex'
              (X        => Clip_X (X1),
               Y        => Clip_Y (Y1),
               U        => 0.0,
               V        => 0.0,
               Color    => Color,
               Textured => False,
               Texture  => Texture_None));
         Result.Vertices.Append
           (Vertex'
              (X        => Clip_X (X2),
               Y        => Clip_Y (Y2),
               U        => 0.0,
               V        => 0.0,
               Color    => Color,
               Textured => False,
               Texture  => Texture_None));
         Result.Vertices.Append
           (Vertex'
              (X        => Clip_X (X3),
               Y        => Clip_Y (Y3),
               U        => 0.0,
               V        => 0.0,
               Color    => Color,
               Textured => False,
               Texture  => Texture_None));
      end Append_Triangle;

      procedure Build_Icon_Atlas is
         Tile_Size  : constant Positive := Icon_Atlas_Tile_Size;
         Icon_Count : Natural := 0;

         procedure Append_Clear_Pixels
           (Count : Natural) is
         begin
            for Index in 1 .. Count loop
               Result.Icon_Atlas_Pixels.Append (0);
            end loop;
         end Append_Clear_Pixels;

         procedure Put_Pixel
           (X : Natural;
            Y : Natural;
            R : Interfaces.Unsigned_8;
            G : Interfaces.Unsigned_8;
            B : Interfaces.Unsigned_8;
            A : Interfaces.Unsigned_8)
         is
            Offset : constant Positive :=
              Positive (((Y * Result.Icon_Atlas_Width) + X) * Result.Icon_Atlas_Channels + 1);
         begin
            Result.Icon_Atlas_Pixels.Replace_Element (Offset, R);
            Result.Icon_Atlas_Pixels.Replace_Element (Offset + 1, G);
            Result.Icon_Atlas_Pixels.Replace_Element (Offset + 2, B);
            Result.Icon_Atlas_Pixels.Replace_Element (Offset + 3, A);
         end Put_Pixel;

         procedure Role_Color
           (Icon_Id : String;
            Role    : Files.Rendering.Icon_Asset_Color_Role;
            R       : out Interfaces.Unsigned_8;
            G       : out Interfaces.Unsigned_8;
            B       : out Interfaces.Unsigned_8;
            A       : out Interfaces.Unsigned_8)
         is
         begin
            case Role is
               when Files.Rendering.Icon_Asset_Base =>
                  if Icon_Id = "folder" then
                     R := 82;
                     G := 128;
                     B := 209;
                  else
                     R := 184;
                     G := 190;
                     B := 198;
                  end if;
               when Files.Rendering.Icon_Asset_Accent =>
                  R := 57;
                  G := 127;
                  B := 218;
               when Files.Rendering.Icon_Asset_Border =>
                  R := 30;
                  G := 35;
                  B := 42;
               when Files.Rendering.Icon_Asset_Muted =>
                  R := 112;
                  G := 120;
                  B := 130;
            end case;
            A := 255;
         end Role_Color;

         procedure Rasterize_Asset
           (Tile_Index : Natural;
            Icon       : Files.Rendering.Icon_Command)
         is
            Asset_Text : constant String :=
              Files.Rendering.Icon_Asset_Text (To_String (Icon.Icon_Id), To_String (Icon.Theme_Name));
            Asset      : Files.Rendering.Icon_Asset := Files.Rendering.Parse_Icon_Asset (Asset_Text);
            Tile_X     : constant Natural := Tile_Index * Tile_Size;

            procedure Fill_Rect
              (Rect : Files.Rendering.Icon_Asset_Rect)
            is
               X0 : constant Natural :=
                 Saturating_Add
                   (Tile_X,
                    Bounded_Product_Divide (Value => Rect.Grid_X, Factor => Tile_Size, Denominator => Asset.Grid));
               Y0 : constant Natural :=
                 Bounded_Product_Divide (Value => Rect.Grid_Y, Factor => Tile_Size, Denominator => Asset.Grid);
               X1 : constant Natural :=
                 Natural'Min
                   (Saturating_Add (Tile_X, Tile_Size),
                    Saturating_Add
                      (Tile_X,
                       Bounded_Product_Divide
                         (Value       => Rect.Grid_X + Rect.Grid_W,
                          Factor      => Tile_Size,
                          Denominator => Asset.Grid)));
               Y1 : constant Natural :=
                 Natural'Min
                   (Tile_Size,
                    Bounded_Product_Divide
                      (Value => Rect.Grid_Y + Rect.Grid_H, Factor => Tile_Size, Denominator => Asset.Grid));
               R  : Interfaces.Unsigned_8;
               G  : Interfaces.Unsigned_8;
               B  : Interfaces.Unsigned_8;
               A  : Interfaces.Unsigned_8;
            begin
               if X1 <= X0 or else Y1 <= Y0 then
                  return;
               end if;

               Role_Color (To_String (Icon.Icon_Id), Rect.Role, R, G, B, A);
               for Y in Y0 .. Y1 - 1 loop
                  for X in X0 .. X1 - 1 loop
                     Put_Pixel (X, Y, R, G, B, A);
                  end loop;
               end loop;
            end Fill_Rect;

            function Rasterize_Thumbnail return Boolean is
               Source_Width  : constant Natural := Icon.Thumbnail_Width;
               Source_Height : constant Natural := Icon.Thumbnail_Height;
               Tile_X        : constant Natural := Tile_Index * Tile_Size;
            begin
               if Source_Width = 0
                 or else Source_Height = 0
                 or else Natural (Icon.Thumbnail_Pixels.Length) /= Source_Width * Source_Height * 4
               then
                  return False;
               end if;

               for Y in 0 .. Tile_Size - 1 loop
                  for X in 0 .. Tile_Size - 1 loop
                     declare
                        Source_X : constant Natural := (X * Source_Width) / Tile_Size;
                        Source_Y : constant Natural := (Y * Source_Height) / Tile_Size;
                        Offset   : constant Positive :=
                          Positive (((Source_Y * Source_Width) + Source_X) * 4 + 1);
                     begin
                        Put_Pixel
                          (Tile_X + X,
                           Y,
                           Icon.Thumbnail_Pixels.Element (Offset),
                           Icon.Thumbnail_Pixels.Element (Offset + 1),
                           Icon.Thumbnail_Pixels.Element (Offset + 2),
                           Icon.Thumbnail_Pixels.Element (Offset + 3));
                     end;
                  end loop;
               end loop;

               return True;
            end Rasterize_Thumbnail;
         begin
            if Rasterize_Thumbnail then
               return;
            end if;

            if not Asset.Valid then
               Asset :=
                 Files.Rendering.Parse_Icon_Asset
                   (Files.Rendering.Icon_Asset_Text ("unknown", To_String (Icon.Theme_Name)));
            end if;

            if Asset.Valid then
               for Rect of Asset.Rectangles loop
                  Fill_Rect (Rect);
               end loop;
            end if;
         end Rasterize_Asset;

         Tile_Index : Natural := 0;
      begin
         for Icon of Frame.Icons loop
            if not Is_Toolbar_Icon (To_String (Icon.Icon_Id)) then
               Icon_Count := Icon_Count + 1;
            end if;
         end loop;

         if Icon_Count = 0
           or else Icon_Count > Max_Icon_Atlas_Tiles
         then
            return;
         end if;

         Result.Icon_Atlas_Width := Icon_Count * Tile_Size;
         Result.Icon_Atlas_Height := Tile_Size;
         Result.Icon_Atlas_Channels := Icon_Atlas_Channels;
         Result.Icon_Atlas_Bytes :=
           Result.Icon_Atlas_Width * Result.Icon_Atlas_Height * Result.Icon_Atlas_Channels;
         Result.Icon_Atlas_Dirty := True;
         Append_Clear_Pixels (Result.Icon_Atlas_Bytes);

         for Icon of Frame.Icons loop
            if not Is_Toolbar_Icon (To_String (Icon.Icon_Id)) then
               Rasterize_Asset (Tile_Index, Icon);
               Tile_Index := Tile_Index + 1;
            end if;
         end loop;
      end Build_Icon_Atlas;
   begin
      Result.Width := Frame.Layout.Width;
      Result.Height := Frame.Layout.Height;
      Result.Atlas_Width := Text.Atlas_Width;
      Result.Atlas_Height := Text.Atlas_Height;
      Result.Atlas_Pixels := Text.Atlas_Pixels;
      Result.Atlas_Bytes := Text.Atlas_Bytes;
      Result.Atlas_Dirty := Text.Atlas_Dirty;
      Result.Text_Atlas_Used :=
        Text.Status = Files.Rendering.Text_Render_Success
        and then
          (not Text.Glyphs.Is_Empty
           or else not Text.Overlay_Glyphs.Is_Empty);
      Build_Icon_Atlas;
      Result.Icon_Texture_Format := Icon_Upload_Texture_Format (Result);
      Result.Texture_Count :=
        (if Result.Atlas_Dirty and then Result.Icon_Atlas_Dirty then 2
         elsif Result.Atlas_Dirty or else Result.Icon_Atlas_Dirty then 1
         else 0);
      Result.Uses_Separate_Text_And_Icon_Textures :=
        Result.Text_Atlas_Used and then Result.Icon_Atlas_Dirty;

      for Rectangle of Frame.Rectangles loop
         declare
            Before : constant Natural := Natural (Result.Vertices.Length);
         begin
            Append_Quad
              (X        => Float (Rectangle.X),
               Y        => Float (Rectangle.Y),
               Width    => Float (Rectangle.Width),
               Height   => Float (Rectangle.Height),
               U0       => 0.0,
               V0       => 0.0,
               U1       => 0.0,
               V1       => 0.0,
               Color    => Rectangle.Color,
               Textured => False,
               Texture  => Texture_None);
            Result.Rectangle_Vertex_Count :=
              Result.Rectangle_Vertex_Count + Natural (Result.Vertices.Length) - Before;
         end;
      end loop;

      for Triangle of Frame.Triangles loop
         declare
            Before : constant Natural := Natural (Result.Vertices.Length);
         begin
            Append_Triangle
              (X1    => Triangle.X1,
               Y1    => Triangle.Y1,
               X2    => Triangle.X2,
               Y2    => Triangle.Y2,
               X3    => Triangle.X3,
               Y3    => Triangle.Y3,
               Color => Triangle.Color);
            Result.Triangle_Vertex_Count :=
              Result.Triangle_Vertex_Count + Natural (Result.Vertices.Length) - Before;
         end;
      end loop;

      if Result.Icon_Atlas_Dirty then
         declare
            Source_Icon_Index : Natural := 0;
            Icon_Count : Natural := 0;
         begin
            for Icon of Frame.Icons loop
               if not Is_Toolbar_Icon (To_String (Icon.Icon_Id)) then
                  Icon_Count := Icon_Count + 1;
               end if;
            end loop;

            for Icon of Frame.Icons loop
               if not Is_Toolbar_Icon (To_String (Icon.Icon_Id)) then
                  declare
                     Before : constant Natural := Natural (Result.Vertices.Length);
                     U0     : constant Float :=
                       (if Icon_Count = 0
                        then 0.0
                        else Float (Source_Icon_Index) / Float (Icon_Count));
                     U1     : constant Float :=
                       (if Icon_Count = 0
                        then 0.0
                        else Float (Source_Icon_Index + 1) / Float (Icon_Count));
                  begin
                     Append_Quad
                       (X        => Float (Icon.X),
                        Y        => Float (Icon.Y),
                        Width    => Float (Icon.Size),
                        Height   => Float (Icon.Size),
                        U0       => U0,
                        V0       => 0.0,
                        U1       => U1,
                        V1       => 1.0,
                        Color    => Files.Rendering.Icon_File_Color,
                        Textured => True,
                        Texture  => Texture_Icon_Atlas);
                     Result.Icon_Vertex_Count :=
                       Result.Icon_Vertex_Count + Natural (Result.Vertices.Length) - Before;
                     if Natural (Result.Vertices.Length) > Before then
                        Result.Icon_Quad_Count := Result.Icon_Quad_Count + 1;
                     end if;
                     Source_Icon_Index := Source_Icon_Index + 1;
                  end;
               end if;
            end loop;
         end;
      end if;

      if Text.Status = Files.Rendering.Text_Render_Success then
         for Glyph of Text.Glyphs loop
            declare
               Before : constant Natural := Natural (Result.Vertices.Length);
            begin
               Append_Quad
                 (X        => Glyph.X,
                  Y        => Glyph.Y,
                  Width    => Glyph.Width,
                  Height   => Glyph.Height,
                  U0       => Glyph.U0,
                  V0       => Glyph.V0,
                  U1       => Glyph.U1,
                  V1       => Glyph.V1,
                  Color    => Glyph.Color,
                  Textured => True,
                  Texture  => Texture_Text_Atlas);
               Result.Glyph_Vertex_Count :=
                 Result.Glyph_Vertex_Count + Natural (Result.Vertices.Length) - Before;
            end;
         end loop;

         for Rectangle of Frame.Overlay_Rectangles loop
            declare
               Before : constant Natural := Natural (Result.Vertices.Length);
            begin
               Append_Quad
                 (X        => Float (Rectangle.X),
                  Y        => Float (Rectangle.Y),
                  Width    => Float (Rectangle.Width),
                  Height   => Float (Rectangle.Height),
                  U0       => 0.0,
                  V0       => 0.0,
                  U1       => 0.0,
                  V1       => 0.0,
                  Color    => Rectangle.Color,
                  Textured => False,
                  Texture  => Texture_None);
               Result.Overlay_Vertex_Count :=
                 Result.Overlay_Vertex_Count + Natural (Result.Vertices.Length) - Before;
            end;
         end loop;

         for Glyph of Text.Overlay_Glyphs loop
            declare
               Before : constant Natural := Natural (Result.Vertices.Length);
            begin
               Append_Quad
                 (X        => Glyph.X,
                  Y        => Glyph.Y,
                  Width    => Glyph.Width,
                  Height   => Glyph.Height,
                  U0       => Glyph.U0,
                  V0       => Glyph.V0,
                  U1       => Glyph.U1,
                  V1       => Glyph.V1,
                  Color    => Glyph.Color,
                  Textured => True,
                  Texture  => Texture_Text_Atlas);
               Result.Overlay_Vertex_Count :=
                 Result.Overlay_Vertex_Count + Natural (Result.Vertices.Length) - Before;
            end;
         end loop;
      end if;

      return Result;
   end Build_Submission;

   function Compare_Gpu_Screenshot
     (Actual   : Submission_Batch;
      Expected : Submission_Batch)
      return Gpu_Screenshot_Comparison
   is
      function Natural_Code
        (Value : Natural)
         return Interfaces.Unsigned_32 is
      begin
         return Interfaces.Unsigned_32 (Value mod 2_147_483_647);
      end Natural_Code;

      function Float_Code
        (Value : Float)
         return Interfaces.Unsigned_32
      is
         Scaled : constant Integer := Integer (Value * 10_000.0);
      begin
         return Interfaces.Unsigned_32 (Scaled + 2_000_000);
      end Float_Code;

      function Boolean_Code
        (Value : Boolean)
         return Interfaces.Unsigned_32 is
      begin
         return (if Value then 1 else 0);
      end Boolean_Code;

      function Batch_Hash
        (Batch : Submission_Batch)
         return Interfaces.Unsigned_32
      is
         Hash : Interfaces.Unsigned_32 := 2_166_136_261;

         procedure Mix
           (Value : Interfaces.Unsigned_32) is
         begin
            Hash := (Hash xor Value) * 16_777_619;
         end Mix;
      begin
         Mix (Natural_Code (Batch.Width));
         Mix (Natural_Code (Batch.Height));
         Mix (Natural_Code (Batch.Rectangle_Vertex_Count));
         Mix (Natural_Code (Batch.Triangle_Vertex_Count));
         Mix (Natural_Code (Batch.Icon_Vertex_Count));
         Mix (Natural_Code (Batch.Icon_Quad_Count));
         Mix (Natural_Code (Batch.Glyph_Vertex_Count));
         Mix (Natural_Code (Batch.Overlay_Vertex_Count));
         Mix (Natural_Code (Batch.Texture_Count));
         Mix (Boolean_Code (Batch.Text_Atlas_Used));
         Mix (Boolean_Code (Batch.Uses_Separate_Text_And_Icon_Textures));
         Mix (Natural_Code (Natural (Batch.Vertices.Length)));

         for Item of Batch.Vertices loop
            Mix (Float_Code (Item.X));
            Mix (Float_Code (Item.Y));
            Mix (Float_Code (Item.U));
            Mix (Float_Code (Item.V));
            Mix (Natural_Code (Files.Rendering.Render_Color'Pos (Item.Color)));
            Mix (Boolean_Code (Item.Textured));
            Mix (Natural_Code (Texture_Source'Pos (Item.Texture)));
         end loop;

         return Hash;
      end Batch_Hash;

      Actual_Hash   : constant Interfaces.Unsigned_32 := Batch_Hash (Actual);
      Expected_Hash : constant Interfaces.Unsigned_32 := Batch_Hash (Expected);
   begin
      return
        (Supported         => True,
         Matched           => Actual_Hash = Expected_Hash,
         Width             => Actual.Width,
         Height            => Actual.Height,
         Compared_Vertices =>
           Natural'Min (Natural (Actual.Vertices.Length), Natural (Expected.Vertices.Length)),
         Actual_Hash       => Actual_Hash,
         Expected_Hash     => Expected_Hash);
   end Compare_Gpu_Screenshot;

   function Present
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Vulkan_Status is
      Image_Index : aliased Interfaces.Unsigned_32 := 0;
      Swapchains  : aliased Swapchain_Array (1 .. 1) := [1 => Renderer.Swapchain];
      Indices     : aliased Image_Index_Array (1 .. 1);
      Present_Waits : aliased Semaphore_Array (1 .. 1) := [1 => Renderer.Render_Finished];
      Submit_Waits  : aliased Semaphore_Array (1 .. 1) := [1 => Renderer.Image_Available];
      Submit_Signals : aliased Semaphore_Array (1 .. 1) := [1 => Renderer.Render_Finished];
      Wait_Stages : aliased Interfaces.Unsigned_32 := Vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
      Fence_Array : aliased Fence_Array_C (1 .. 1) := [1 => Renderer.In_Flight];
      Submit_Commands : aliased Command_Buffer_Array_C (1 .. 1);
      Submit_Info : aliased Vk.Submit_Info_T :=
        (s_Type                 => Vk.STRUCTURE_TYPE_SUBMIT_INFO,
         p_Next                 => System.Null_Address,
         wait_Semaphore_Count   => 1,
         p_Wait_Semaphores      => Submit_Waits'Address,
         p_Wait_Dst_Stage_Mask  => Wait_Stages'Address,
         command_Buffer_Count   => 1,
         p_Command_Buffers      => Submit_Commands'Address,
         signal_Semaphore_Count => 1,
         p_Signal_Semaphores    => Submit_Signals'Address);
      Present_Info : aliased Vk.Present_Info_KHR_T :=
        (s_Type               => Structure_Type_Present_Info_KHR,
         p_Next               => System.Null_Address,
         wait_Semaphore_Count => 1,
         p_Wait_Semaphores    => Present_Waits'Address,
         swapchain_Count      => 1,
         p_Swapchains         => Swapchains'Address,
         p_Image_Indices      => Indices'Address,
         p_Results            => System.Null_Address);
      Present_Result : Vk.Result_T;
   begin
      Renderer.Last_Vk_Result := -10_000;
      Renderer.Last_Vertex_Count := Natural (Batch.Vertices.Length);
      Renderer.Last_Texture_Count := Batch.Texture_Count;
      Renderer.Last_Used_Mixed_Textures := Batch.Uses_Separate_Text_And_Icon_Textures;

      if not Renderer.Device_Live or else not Renderer.Surface_Live then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif not Renderer.Swapchain_Configured
        or else not Renderer.Swapchain_Live
        or else not Renderer.Sync_Live
        or else not Renderer.Commands_Live
        or else Renderer.Graphics_Queue = System.Null_Address
      then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif Batch.Width = 0
        or else Batch.Height = 0
        or else Batch.Vertices.Is_Empty
      then
         Renderer.Last_Status := Vulkan_Present_Skipped;
      elsif Batch.Width /= Renderer.Frame_Width_Value
        or else Batch.Height /= Renderer.Frame_Height_Value
      then
         Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
         Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
      else
         Renderer.Last_Vk_Result := -10_010;
         Present_Result :=
           Vk.Wait_For_Fences
             (device      => Renderer.Device,
              fence_Count => 1,
              p_Fences    => Fence_Array'Address,
              wait_All    => 1,
              timeout     => Infinite_Timeout);

         if Present_Result /= Vk.SUCCESS then
            Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
            Renderer.Last_Status := Vulkan_Submit_Failed;
         else
            if Renderer.Readback_Enabled then
               Capture_Completed_Readback (Renderer);
            end if;
            Renderer.Last_Vk_Result := -10_020;
            if not Upload_Vertices (Renderer, Batch) then
               Renderer.Last_Status := Vulkan_Vertex_Buffer_Create_Failed;
            elsif not Upload_Atlas (Renderer, Batch) then
               Renderer.Last_Status := Vulkan_Atlas_Texture_Create_Failed;
            elsif Batch.Uses_Separate_Text_And_Icon_Textures
              and then not Upload_Icon_Atlas (Renderer, Batch)
            then
               Renderer.Last_Status := Vulkan_Atlas_Texture_Create_Failed;
            elsif Renderer.Readback_Enabled
              and then not Ensure_Readback_Buffer
                (Renderer,
                 Saturating_Multiply (Saturating_Multiply (Batch.Width, Batch.Height), 4))
            then
               Renderer.Last_Status := Vulkan_Vertex_Buffer_Create_Failed;
            else
               Renderer.Last_Vk_Result := -10_030;
               Present_Result :=
                 Vk.Acquire_Next_Image_KHR
                   (device        => Renderer.Device,
                    swapchain     => Renderer.Swapchain,
                    timeout       => Infinite_Timeout,
                    semaphore     => Renderer.Image_Available,
                    fence         => System.Null_Address,
                    p_Image_Index => Image_Index'Address);

               if Present_Result = Error_Out_Of_Date_KHR then
                  Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                  Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
                  Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
               elsif Present_Result /= Vk.SUCCESS and then Present_Result /= Suboptimal_KHR then
                  Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                  Renderer.Last_Status := Vulkan_Present_Failed;
               elsif not Record_Command_Buffers (Renderer, Natural (Batch.Vertices.Length)) then
                  Renderer.Last_Status := Vulkan_Command_Record_Failed;
               else
                  Renderer.Last_Vk_Result := -10_040;
                  Renderer.Current_Image_Index := Image_Index;
                  Indices (1) := Image_Index;
                  Submit_Commands (1) := Renderer.Command_Buffers (Positive (Image_Index + 1));
                  Renderer.Last_Vk_Result := -10_050;
                  Present_Result :=
                    Vk.Reset_Fences
                      (device      => Renderer.Device,
                       fence_Count => 1,
                       p_Fences    => Fence_Array'Address);

                  if Present_Result /= Vk.SUCCESS then
                     Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                     Renderer.Last_Status := Vulkan_Submit_Failed;
                  else
                     Renderer.Last_Vk_Result := -10_060;
                     Present_Result :=
                       Vk.Queue_Submit
                         (queue        => Renderer.Graphics_Queue,
                          submit_Count => 1,
                          p_Submits    => Submit_Info'Address,
                          fence        => Renderer.In_Flight);

                     if Present_Result /= Vk.SUCCESS then
                        Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                        Renderer.Last_Status := Vulkan_Submit_Failed;
                     else
                        Renderer.Readback_Pending := Renderer.Readback_Enabled;
                        Renderer.Last_Vk_Result := -10_070;
                        Present_Result :=
                          Vk.Queue_Present_KHR
                            (queue          => Renderer.Graphics_Queue,
                             p_Present_Info => Present_Info'Address);

                        if Present_Result = Vk.SUCCESS then
                           Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                           Renderer.Last_Status := Vulkan_Presented;
                        elsif Present_Result = Suboptimal_KHR or else Present_Result = Error_Out_Of_Date_KHR then
                           Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                           Request_Swapchain_Recreate (Renderer, Batch.Width, Batch.Height);
                           Renderer.Last_Status := Vulkan_Swapchain_Recreate_Needed;
                        else
                           Renderer.Last_Vk_Result := Interfaces.Integer_32 (Present_Result);
                           Renderer.Last_Status := Vulkan_Present_Failed;
                        end if;
                     end if;
                  end if;
               end if;
            end if;
         end if;
      end if;

      case Renderer.Last_Status is
         when Vulkan_Presented =>
            Renderer.Presented_Frames := Renderer.Presented_Frames + 1;
         when Vulkan_Present_Skipped | Vulkan_Swapchain_Recreate_Needed =>
            Renderer.Skipped_Frames := Renderer.Skipped_Frames + 1;
         when Vulkan_Present_Failed
            | Vulkan_Submit_Failed
            | Vulkan_Command_Record_Failed
            | Vulkan_Vertex_Buffer_Create_Failed
            | Vulkan_Atlas_Texture_Create_Failed =>
            Renderer.Failed_Frames := Renderer.Failed_Frames + 1;
         when others =>
            null;
      end case;

      return Renderer.Last_Status;
   exception
      when others =>
         Renderer.Last_Status := Vulkan_Present_Failed;
         Renderer.Failed_Frames := Renderer.Failed_Frames + 1;
         return Renderer.Last_Status;
   end Present;

end Files.Rendering.Vulkan;
