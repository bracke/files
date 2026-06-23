with Interfaces;
with System;

with Ada.Containers.Vectors;

with Glfw.Windows;
with Vk;

--  Vulkan renderer lifecycle backed by df_vulkan.
package Files.Rendering.Vulkan is
   use type Interfaces.Unsigned_8;

   type Vulkan_Status is
     (Vulkan_Not_Initialized,
      Vulkan_Ready,
      Vulkan_Instance_Create_Failed,
      Vulkan_Device_Create_Failed,
      Vulkan_Surface_Unsupported,
      Vulkan_Surface_Create_Failed,
      Vulkan_Surface_Ready,
      Vulkan_Swapchain_Ready,
      Vulkan_Swapchain_Recreate_Needed,
      Vulkan_Swapchain_Create_Failed,
      Vulkan_Swapchain_Image_Query_Failed,
      Vulkan_Render_Target_Create_Failed,
      Vulkan_Command_Create_Failed,
      Vulkan_Command_Record_Failed,
      Vulkan_Pipeline_Create_Failed,
      Vulkan_Vertex_Buffer_Create_Failed,
      Vulkan_Atlas_Texture_Create_Failed,
      Vulkan_Descriptor_Create_Failed,
      Vulkan_Sync_Create_Failed,
      Vulkan_Submit_Failed,
      Vulkan_Presented,
      Vulkan_Present_Skipped,
      Vulkan_Present_Failed);

   type Vulkan_Renderer is private;

   type Texture_Source is
     (Texture_None,
      Texture_Text_Atlas,
      Texture_Icon_Atlas);

   type Atlas_Texture_Format is
     (Atlas_Texture_None,
      Atlas_Texture_R8,
      Atlas_Texture_RGBA8);

   type Vertex is record
      X       : Float := 0.0;
      Y       : Float := 0.0;
      U       : Float := 0.0;
      V       : Float := 0.0;
      Color   : Files.Rendering.Render_Color := Files.Rendering.Canvas_Color;
      Textured : Boolean := False;
      Texture : Texture_Source := Texture_None;
   end record;

   package Vertex_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Vertex);

   package Icon_Atlas_Pixel_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Interfaces.Unsigned_8);

   type Submission_Batch is record
      Vertices               : Vertex_Vectors.Vector;
      Rectangle_Vertex_Count : Natural := 0;
      Triangle_Vertex_Count  : Natural := 0;
      Icon_Vertex_Count      : Natural := 0;
      Icon_Quad_Count        : Natural := 0;
      Glyph_Vertex_Count     : Natural := 0;
      Overlay_Vertex_Count   : Natural := 0;
      Width                  : Natural := 0;
      Height                 : Natural := 0;
      Atlas_Width            : Natural := 0;
      Atlas_Height           : Natural := 0;
      Atlas_Pixels           : System.Address := System.Null_Address;
      Atlas_Bytes            : Natural := 0;
      Atlas_Dirty            : Boolean := False;
      Text_Atlas_Used        : Boolean := False;
      Texture_Count          : Natural := 0;
      Uses_Separate_Text_And_Icon_Textures : Boolean := False;
      Icon_Texture_Format    : Atlas_Texture_Format := Atlas_Texture_None;
      Icon_Atlas_Width       : Natural := 0;
      Icon_Atlas_Height      : Natural := 0;
      Icon_Atlas_Channels    : Natural := 0;
      Icon_Atlas_Pixels      : Icon_Atlas_Pixel_Vectors.Vector;
      Icon_Atlas_Bytes       : Natural := 0;
      Icon_Atlas_Dirty       : Boolean := False;
   end record;

   type Gpu_Screenshot_Comparison is record
      Supported         : Boolean := True;
      Matched           : Boolean := False;
      Width             : Natural := 0;
      Height            : Natural := 0;
      Compared_Vertices : Natural := 0;
      Actual_Hash       : Interfaces.Unsigned_32 := 0;
      Expected_Hash     : Interfaces.Unsigned_32 := 0;
   end record;

   --  Return the Vulkan upload texture format implied by Batch.
   --
   --  @param Batch Submission batch to inspect.
   --  @return Texture format required by the atlas selected for upload.
   function Upload_Texture_Format
     (Batch : Submission_Batch)
      return Atlas_Texture_Format;

   --  Return the Vulkan upload texture format required by Batch's icon atlas.
   --
   --  @param Batch Submission batch to inspect.
   --  @return Texture format required by the icon atlas upload, or none.
   function Icon_Upload_Texture_Format
     (Batch : Submission_Batch)
      return Atlas_Texture_Format;

   type Renderer_Diagnostics is record
      Device_Ready          : Boolean := False;
      Surface_Ready         : Boolean := False;
      Swapchain_Ready       : Boolean := False;
      Swapchain_Recreate    : Boolean := False;
      Render_Targets_Ready  : Boolean := False;
      Commands_Ready        : Boolean := False;
      Sync_Ready            : Boolean := False;
      Pipeline_Ready        : Boolean := False;
      Descriptor_Ready      : Boolean := False;
      Texture_Binding_Count : Natural := 0;
      Mixed_Texture_Bindings_Ready : Boolean := False;
      Vertex_Buffer_Ready   : Boolean := False;
      Atlas_Texture_Ready   : Boolean := False;
      Icon_Atlas_Texture_Ready : Boolean := False;
      Resize_Validated      : Boolean := False;
      Long_Running_Validated : Boolean := False;
      Device_Loss_Handled   : Boolean := False;
      Surface_Loss_Handled  : Boolean := False;
      Multi_Window_Validated : Boolean := False;
      Resize_Validation_Planned : Boolean := True;
      Device_Loss_Validation_Planned : Boolean := True;
      Surface_Loss_Validation_Planned : Boolean := True;
      Multi_Window_Validation_Planned : Boolean := True;
      Long_Running_Validation_Planned : Boolean := True;
      Presented_Frames      : Natural := 0;
      Skipped_Frames        : Natural := 0;
      Failed_Frames         : Natural := 0;
      Last_Vertex_Count     : Natural := 0;
      Last_Texture_Count    : Natural := 0;
      Last_Used_Mixed_Textures : Boolean := False;
      Framebuffer_Readback_Enabled : Boolean := False;
      Framebuffer_Readback_Ready : Boolean := False;
      Last_Framebuffer_Hash : Interfaces.Unsigned_32 := 0;
      Last_Framebuffer_Bytes : Natural := 0;
      Frame_Width           : Natural := 0;
      Frame_Height          : Natural := 0;
      Pending_Frame_Width   : Natural := 0;
      Pending_Frame_Height  : Natural := 0;
      Last_Status           : Vulkan_Status := Vulkan_Not_Initialized;
      Last_Vk_Result        : Interfaces.Integer_32 := 0;
      Physical_Device_Count : Interfaces.Unsigned_32 := 0;
   end record;

   type Resize_Validation_Result is record
      Requested_Width     : Natural := 0;
      Requested_Height    : Natural := 0;
      Recreate_Requested  : Boolean := False;
      Pending_Width       : Natural := 0;
      Pending_Height      : Natural := 0;
      Status              : Vulkan_Status := Vulkan_Not_Initialized;
   end record;

   type Runtime_Validation_Result is record
      Requested       : Boolean := False;
      Handled         : Boolean := False;
      Device_Ready    : Boolean := False;
      Surface_Ready   : Boolean := False;
      Swapchain_Ready : Boolean := False;
      Status          : Vulkan_Status := Vulkan_Not_Initialized;
   end record;

   type Runtime_Validation_Plan is record
      Validate_Resize       : Boolean := True;
      Validate_Device_Loss  : Boolean := True;
      Validate_Surface_Loss : Boolean := True;
      Validate_Multi_Window : Boolean := True;
      Validate_Long_Running : Boolean := True;
      Width                 : Natural := 640;
      Height                : Natural := 360;
      Frame_Count           : Positive := 1;
      Window_Count          : Positive := 1;
   end record;

   type Runtime_Validation_Suite_Result is record
      Resize_Validated       : Boolean := False;
      Device_Loss_Handled    : Boolean := False;
      Surface_Loss_Handled   : Boolean := False;
      Multi_Window_Validated : Boolean := False;
      Long_Running_Validated : Boolean := False;
      Frames_Attempted       : Natural := 0;
      Frames_Presented       : Natural := 0;
      Frames_Skipped         : Natural := 0;
      Frames_Failed          : Natural := 0;
      Last_Status            : Vulkan_Status := Vulkan_Not_Initialized;
   end record;

   --  Initialize Vulkan instance and logical device state.
   --
   --  @param Renderer Renderer state to initialize.
   --  @return Vulkan initialization status.
   function Initialize
     (Renderer : in out Vulkan_Renderer)
      return Vulkan_Status;

   --  Release Vulkan resources held by Renderer.
   --
   --  @param Renderer Renderer state to shut down.
   procedure Shutdown
     (Renderer : in out Vulkan_Renderer);

   --  Return whether Renderer has a live Vulkan device.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return True when Renderer can accept frame submission.
   function Ready
     (Renderer : Vulkan_Renderer)
      return Boolean;

   --  Return the last initialization status.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Last Vulkan status stored on Renderer.
   function Status
     (Renderer : Vulkan_Renderer)
      return Vulkan_Status;

   --  Return the physical device count observed during initialization.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Physical device count reported by Vulkan.
   function Physical_Device_Count
     (Renderer : Vulkan_Renderer)
      return Interfaces.Unsigned_32;

   --  Create a Vulkan window surface for Renderer.
   --
   --  @param Renderer Renderer with a live Vulkan instance.
   --  @param Window GLFW window to attach to Vulkan.
   --  @return Surface creation status.
   function Create_Surface
     (Renderer : in out Vulkan_Renderer;
      Window   : not null access Glfw.Windows.Window)
      return Vulkan_Status;

   --  Return whether Renderer has a live window surface.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return True when Renderer owns a live Vulkan surface.
   function Surface_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean;

   --  Configure the presentation extent used by the swapchain path.
   --
   --  @param Renderer Renderer with a live device and surface.
   --  @param Width Framebuffer width in pixels.
   --  @param Height Framebuffer height in pixels.
   --  @return Swapchain configuration status.
   function Configure_Swapchain
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Vulkan_Status;

   --  Mark the swapchain as needing recreation for a new framebuffer extent.
   --
   --  @param Renderer Renderer state to update.
   --  @param Width Requested framebuffer width in pixels.
   --  @param Height Requested framebuffer height in pixels.
   procedure Request_Swapchain_Recreate
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural);

   --  Validate resize handling by routing through swapchain recreation state.
   --
   --  @param Renderer Renderer state to update.
   --  @param Width Requested framebuffer width in pixels.
   --  @param Height Requested framebuffer height in pixels.
   --  @return Resize validation result after recreation is requested.
   function Validate_Resize_Request
     (Renderer : in out Vulkan_Renderer;
      Width    : Natural;
      Height   : Natural)
      return Resize_Validation_Result;

   --  Validate device-loss handling by routing through renderer shutdown.
   --
   --  @param Renderer Renderer state to update.
   --  @return Runtime validation result after device-loss handling.
   function Validate_Device_Loss
     (Renderer : in out Vulkan_Renderer)
      return Runtime_Validation_Result;

   --  Validate surface-loss handling by releasing swapchain-bound state.
   --
   --  @param Renderer Renderer state to update.
   --  @return Runtime validation result after surface-loss handling.
   function Validate_Surface_Loss
     (Renderer : in out Vulkan_Renderer)
      return Runtime_Validation_Result;

   --  Execute a bounded runtime validation suite against Renderer.
   --
   --  The suite validates resize state, optional batch presentation,
   --  multi-window policy accounting, and loss handling. Device and surface
   --  loss probes are run last because they release renderer state.
   --
   --  @param Renderer Renderer state to validate.
   --  @param Batch Prepared batch used for presentation validation.
   --  @param Plan Validation scope and frame counts.
   --  @return Structured validation result and frame counters.
   function Validate_Runtime_Suite
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch;
      Plan     : Runtime_Validation_Plan)
      return Runtime_Validation_Suite_Result;

   --  Return whether Renderer has a configured swapchain extent.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return True when Renderer can accept present batches for its extent.
   function Swapchain_Ready
     (Renderer : Vulkan_Renderer)
      return Boolean;

   --  Return whether Renderer has a pending swapchain recreation request.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return True when the next live surface should recreate its swapchain.
   function Swapchain_Recreate_Pending
     (Renderer : Vulkan_Renderer)
      return Boolean;

   --  Return the framebuffer width currently configured for presentation.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Configured framebuffer width in pixels.
   function Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the framebuffer height currently configured for presentation.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Configured framebuffer height in pixels.
   function Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the pending framebuffer width requested for recreation.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Pending framebuffer width in pixels.
   function Pending_Frame_Width
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the pending framebuffer height requested for recreation.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Pending framebuffer height in pixels.
   function Pending_Frame_Height
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the number of successfully presented Vulkan frames.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Count of batches accepted by the Vulkan present path.
   function Presented_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the number of frames skipped by the Vulkan present path.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Count of batches skipped before presentation.
   function Skipped_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the number of failed Vulkan presentation attempts.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Count of presentation failures.
   function Failed_Frame_Count
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return the vertex count in the last submitted batch.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Number of vertices in the last submitted batch.
   function Last_Submitted_Vertex_Count
     (Renderer : Vulkan_Renderer)
      return Natural;

   --  Return a stable diagnostic snapshot for renderer state.
   --
   --  Live presentations copy the completed swapchain image into a readback
   --  buffer and expose its hash through the framebuffer-readback fields.
   --
   --  @param Renderer Renderer state to inspect.
   --  @return Aggregated renderer diagnostics.
   function Diagnostics
     (Renderer : Vulkan_Renderer)
      return Renderer_Diagnostics;

   --  Build a Vulkan-ready quad submission batch from frame and glyph commands.
   --
   --  Rectangles and glyphs are expanded into two triangles each. Coordinates
   --  are normalized to Vulkan clip space, with the top-left frame pixel at
   --  (-1, 1) and the bottom-right pixel at (1, -1).
   --
   --  @param Frame Frame command list containing rectangle commands.
   --  @param Text Text render result containing glyph commands.
   --  @return Submission batch containing quad vertices.
   function Build_Submission
     (Frame : Files.Rendering.Frame_Commands;
      Text  : Files.Rendering.Text_Render_Result)
      return Submission_Batch;

   --  Compare two Vulkan submission batches as deterministic screenshot proxies.
   --
   --  This headless comparison validates the geometry, texture selection, and
   --  color stream that would be submitted to the GPU. Live framebuffer
   --  readback is reported through Diagnostics; this helper remains the
   --  headless CI fallback for environments without a Vulkan window.
   --
   --  @param Actual Batch produced by the rendering path under test.
   --  @param Expected Reference batch for the same frame.
   --  @return Comparison status and stable hashes for diagnostics.
   function Compare_Gpu_Screenshot
     (Actual   : Submission_Batch;
      Expected : Submission_Batch)
      return Gpu_Screenshot_Comparison;

   --  Enable or disable framebuffer readback diagnostics.
   --
   --  @param Renderer Renderer state to update.
   --  @param Enabled True to copy and hash presented frames for diagnostics.
   procedure Set_Readback_Enabled
     (Renderer : in out Vulkan_Renderer;
      Enabled  : Boolean);

   --  Submit a prepared frame batch to the renderer presentation path.
   --
   --  On a live swapchain this records commands and presents the image. When
   --  readback diagnostics are enabled, it also queues framebuffer readback.
   --  Without a live surface it records a skipped presentation without touching
   --  native window state.
   --
   --  @param Renderer Renderer state to present through.
   --  @param Batch Prepared Vulkan submission batch.
   --  @return Presentation status.
   function Present
     (Renderer : in out Vulkan_Renderer;
      Batch    : Submission_Batch)
      return Vulkan_Status;

private
   Max_Swapchain_Images : constant Positive := 8;

   type Swapchain_Image_Array is array (Positive range 1 .. Max_Swapchain_Images) of Vk.Image_T;
   type Image_View_Array is array (Positive range 1 .. Max_Swapchain_Images) of Vk.Image_View_T;
   type Framebuffer_Array is array (Positive range 1 .. Max_Swapchain_Images) of Vk.Framebuffer_T;
   type Command_Buffer_Array is array (Positive range 1 .. Max_Swapchain_Images) of Vk.Command_Buffer_T;

   type Vulkan_Renderer is record
      Instance              : Vk.Instance_T := System.Null_Address;
      Physical_Device       : Vk.Physical_Device_T := System.Null_Address;
      Device                : Vk.Device_T := System.Null_Address;
      Graphics_Queue        : Vk.Queue_T := System.Null_Address;
      Surface               : Vk.Surface_KHR_T := System.Null_Address;
      Swapchain             : Vk.Swapchain_KHR_T := System.Null_Address;
      Render_Pass           : Vk.Render_Pass_T := System.Null_Address;
      Descriptor_Set_Layout : Vk.Descriptor_Set_Layout_T := System.Null_Address;
      Descriptor_Pool       : Vk.Descriptor_Pool_T := System.Null_Address;
      Descriptor_Set        : Vk.Descriptor_Set_T := System.Null_Address;
      Pipeline_Layout       : Vk.Pipeline_Layout_T := System.Null_Address;
      Graphics_Pipeline     : Vk.Pipeline_T := System.Null_Address;
      Command_Pool          : Vk.Command_Pool_T := System.Null_Address;
      Vertex_Buffer         : Vk.Buffer_T := System.Null_Address;
      Vertex_Memory         : Vk.Device_Memory_T := System.Null_Address;
      Atlas_Image           : Vk.Image_T := System.Null_Address;
      Atlas_Memory          : Vk.Device_Memory_T := System.Null_Address;
      Atlas_View            : Vk.Image_View_T := System.Null_Address;
      Atlas_Sampler         : Vk.Sampler_T := System.Null_Address;
      Atlas_Staging_Buffer  : Vk.Buffer_T := System.Null_Address;
      Atlas_Staging_Memory  : Vk.Device_Memory_T := System.Null_Address;
      Icon_Atlas_Image      : Vk.Image_T := System.Null_Address;
      Icon_Atlas_Memory     : Vk.Device_Memory_T := System.Null_Address;
      Icon_Atlas_View       : Vk.Image_View_T := System.Null_Address;
      Icon_Atlas_Sampler    : Vk.Sampler_T := System.Null_Address;
      Icon_Atlas_Staging_Buffer : Vk.Buffer_T := System.Null_Address;
      Icon_Atlas_Staging_Memory : Vk.Device_Memory_T := System.Null_Address;
      Readback_Buffer      : Vk.Buffer_T := System.Null_Address;
      Readback_Memory      : Vk.Device_Memory_T := System.Null_Address;
      Image_Available       : Vk.Semaphore_T := System.Null_Address;
      Render_Finished       : Vk.Semaphore_T := System.Null_Address;
      In_Flight             : Vk.Fence_T := System.Null_Address;
      Swapchain_Images      : Swapchain_Image_Array := [others => System.Null_Address];
      Image_Views           : Image_View_Array := [others => System.Null_Address];
      Framebuffers          : Framebuffer_Array := [others => System.Null_Address];
      Command_Buffers       : Command_Buffer_Array := [others => System.Null_Address];
      Instance_Live         : Boolean := False;
      Device_Live           : Boolean := False;
      Surface_Live          : Boolean := False;
      Swapchain_Live        : Boolean := False;
      Render_Targets_Live   : Boolean := False;
      Descriptor_Live       : Boolean := False;
      Texture_Binding_Count : Natural := 0;
      Pipeline_Live         : Boolean := False;
      Vertex_Buffer_Live    : Boolean := False;
      Atlas_Texture_Live    : Boolean := False;
      Atlas_Staging_Live    : Boolean := False;
      Atlas_Initialized     : Boolean := False;
      Atlas_Upload_Pending  : Boolean := False;
      Icon_Atlas_Texture_Live : Boolean := False;
      Icon_Atlas_Staging_Live : Boolean := False;
      Icon_Atlas_Initialized : Boolean := False;
      Icon_Atlas_Upload_Pending : Boolean := False;
      Commands_Live         : Boolean := False;
      Sync_Live             : Boolean := False;
      Swapchain_Configured  : Boolean := False;
      Swapchain_Pending     : Boolean := False;
      Frame_Width_Value     : Natural := 0;
      Frame_Height_Value    : Natural := 0;
      Queue_Family_Index    : Interfaces.Unsigned_32 := 0;
      Swapchain_Image_Count : Interfaces.Unsigned_32 := 0;
      Render_Target_Count   : Interfaces.Unsigned_32 := 0;
      Command_Buffer_Count  : Interfaces.Unsigned_32 := 0;
      Current_Image_Index   : Interfaces.Unsigned_32 := 0;
      Vertex_Buffer_Capacity : Natural := 0;
      Atlas_Width_Value     : Natural := 0;
      Atlas_Height_Value    : Natural := 0;
      Atlas_Format_Value    : Atlas_Texture_Format := Atlas_Texture_None;
      Atlas_Staging_Capacity : Natural := 0;
      Icon_Atlas_Width_Value : Natural := 0;
      Icon_Atlas_Height_Value : Natural := 0;
      Icon_Atlas_Format_Value : Atlas_Texture_Format := Atlas_Texture_None;
      Icon_Atlas_Staging_Capacity : Natural := 0;
      Readback_Capacity    : Natural := 0;
      Readback_Bytes       : Natural := 0;
      Readback_Enabled     : Boolean := False;
      Readback_Pending     : Boolean := False;
      Readback_Ready       : Boolean := False;
      Last_Readback_Hash   : Interfaces.Unsigned_32 := 0;
      Pending_Width_Value   : Natural := 0;
      Pending_Height_Value  : Natural := 0;
      Presented_Frames      : Natural := 0;
      Skipped_Frames        : Natural := 0;
      Failed_Frames         : Natural := 0;
      Last_Vertex_Count     : Natural := 0;
      Last_Texture_Count    : Natural := 0;
      Last_Used_Mixed_Textures : Boolean := False;
      Last_Status           : Vulkan_Status := Vulkan_Not_Initialized;
      Last_Vk_Result        : Interfaces.Integer_32 := 0;
      Last_Physical_Devices : Interfaces.Unsigned_32 := 0;
      Resize_Validated      : Boolean := False;
      Long_Running_Validated : Boolean := False;
      Multi_Window_Validated : Boolean := False;
      Device_Loss_Validated : Boolean := False;
      Surface_Loss_Validated : Boolean := False;
   end record;

end Files.Rendering.Vulkan;
