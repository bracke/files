with Interfaces.C;

package body Glfw.Windows.Vulkan is
   use type Interfaces.C.int;

   function Glfw_Vulkan_Supported return Interfaces.C.int
     with Import, Convention => C, External_Name => "glfwVulkanSupported";

   function Glfw_Get_Required_Instance_Extensions
     (Count : access Interfaces.Unsigned_32)
      return System.Address
     with Import, Convention => C, External_Name => "glfwGetRequiredInstanceExtensions";

   function Glfw_Create_Window_Surface
     (Instance  : Vk.Instance_T;
      Window    : System.Address;
      Allocator : System.Address;
      Surface   : System.Address)
      return Vk.Result_T
     with Import, Convention => C, External_Name => "glfwCreateWindowSurface";

   function Supported return Boolean is
   begin
      return Glfw_Vulkan_Supported /= 0;
   end Supported;

   function Required_Instance_Extensions
     (Count : out Interfaces.Unsigned_32)
      return System.Address
   is
      Extension_Count : aliased Interfaces.Unsigned_32 := 0;
      Extensions      : constant System.Address :=
        Glfw_Get_Required_Instance_Extensions (Extension_Count'Access);
   begin
      Count := Extension_Count;
      return Extensions;
   end Required_Instance_Extensions;

   function Create_Surface
     (Window   : not null access Glfw.Windows.Window;
      Instance : Vk.Instance_T;
      Surface  : out Vk.Surface_KHR_T)
      return Vk.Result_T
   is
      Created_Surface : aliased Vk.Surface_KHR_T := System.Null_Address;
      Result          : constant Vk.Result_T :=
        Glfw_Create_Window_Surface
          (Instance  => Instance,
           Window    => Window.Handle,
           Allocator => System.Null_Address,
           Surface   => Created_Surface'Address);
   begin
      Surface := Created_Surface;
      return Result;
   end Create_Surface;

end Glfw.Windows.Vulkan;
