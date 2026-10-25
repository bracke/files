with Files.File_System;

--  The native filesystem integration profile of the host this build is for.
package Files.Platform is
   --  Return the native API profile for the current host adapter.
   --
   --  @return Current host native trash and volume binding profile.
   function Current_API_Profile return Files.File_System.Native_Platform_API_Profile;
end Files.Platform;
