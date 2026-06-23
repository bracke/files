package body Files.Platform is
   function Current_API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      return Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Linux);
   end Current_API_Profile;
end Files.Platform;
