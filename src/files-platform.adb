with Files_Config;

package body Files.Platform is
   function Current_API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      --  Report the native adapter for the build's target OS rather than always
      --  claiming Linux. Alire_Host_OS is the compile-time target selector also
      --  used by files.gpr to pick the platform source bodies.
      if Files_Config.Alire_Host_OS = "windows" then
         return Files.File_System.Native_Platform_API_Profile_For
                  (Files.File_System.Native_Adapter_Windows);
      elsif Files_Config.Alire_Host_OS = "macos" then
         return Files.File_System.Native_Platform_API_Profile_For
                  (Files.File_System.Native_Adapter_Macos);
      else
         return Files.File_System.Native_Platform_API_Profile_For
                  (Files.File_System.Native_Adapter_Linux);
      end if;
   end Current_API_Profile;
end Files.Platform;
