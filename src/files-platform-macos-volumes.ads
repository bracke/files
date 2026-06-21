with Files.File_System;

--  macOS volume metadata binding contract.
package Files.Platform.Macos.Volumes is
   --  Return the native macOS volume binding status for this build.
   --
   --  @return Native API binding status.
   function Binding_Status return Files.File_System.Native_API_Binding_Status;

   --  Return whether native macOS volume APIs can be queried.
   --
   --  @return True when volume APIs are available in this build.
   function Can_Query return Boolean;
end Files.Platform.Macos.Volumes;
