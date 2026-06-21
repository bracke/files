with Files.File_System;

--  Windows volume metadata binding contract.
package Files.Platform.Windows.Volumes is
   --  Return the native Windows volume binding status for this build.
   --
   --  @return Native API binding status.
   function Binding_Status return Files.File_System.Native_API_Binding_Status;

   --  Return whether native Windows volume APIs can be queried.
   --
   --  @return True when volume APIs are available in this build.
   function Can_Query return Boolean;
end Files.Platform.Windows.Volumes;
