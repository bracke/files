with Vk;
with Interfaces;
with System;

--  Vulkan helpers for GLFW windows.
package Glfw.Windows.Vulkan is

   --  Return whether GLFW reports Vulkan support.
   --
   --  @return True when GLFW can create Vulkan surfaces.
   function Supported return Boolean;

   --  Return GLFW's required Vulkan instance extension name array.
   --
   --  @param Count Number of extension names returned.
   --  @return Address of GLFW-owned const char* array, or Null_Address.
   function Required_Instance_Extensions
     (Count : out Interfaces.Unsigned_32)
      return System.Address;

   --  Create a Vulkan surface for Window.
   --
   --  @param Window GLFW window to bind to Vulkan.
   --  @param Instance Vulkan instance that owns the surface.
   --  @param Surface Created Vulkan surface on success.
   --  @return Vulkan result code from glfwCreateWindowSurface.
   function Create_Surface
     (Window   : not null access Glfw.Windows.Window;
      Instance : Vk.Instance_T;
      Surface  : out Vk.Surface_KHR_T)
      return Vk.Result_T;

end Glfw.Windows.Vulkan;
