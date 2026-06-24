with Files.File_System;

--  Windows native filesystem integration contracts.
package Files.Platform.Windows is
   --  Return the Windows native API binding profile.
   --
   --  @return Windows trash and volume binding profile.
   function API_Profile return Files.File_System.Native_Platform_API_Profile;

   --  Return the Windows user-default locale name.
   --
   --  @return Locale name from GetUserDefaultLocaleName, or an empty string.
   function Native_Locale return String;

   --  Evaluate whether Request can be handled by the Windows Recycle Bin binding.
   --
   --  @param Request Native trash request to evaluate.
   --  @return Windows native trash result without mutating the filesystem.
   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;

   --  Move Request.Path to the Windows Recycle Bin through the native binding.
   --
   --  @param Request Native trash request to execute.
   --  @return Windows native trash execution result.
   function Move_To_Recycle_Bin
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;
end Files.Platform.Windows;
