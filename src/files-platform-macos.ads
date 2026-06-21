with Files.File_System;

--  macOS native filesystem integration contracts.
package Files.Platform.Macos is
   --  Return the macOS native API binding profile.
   --
   --  @return macOS trash and volume binding profile.
   function API_Profile return Files.File_System.Native_Platform_API_Profile;

   --  Evaluate whether Request can be handled by the macOS trash binding.
   --
   --  @param Request Native trash request to evaluate.
   --  @return macOS native trash result without mutating the filesystem.
   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;

   --  Move Request.Path to trash through the macOS native binding.
   --
   --  @param Request Native trash request to execute.
   --  @return macOS native trash execution result.
   function Move_To_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;
end Files.Platform.Macos;
