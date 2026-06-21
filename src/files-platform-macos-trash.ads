with Files.File_System;

--  macOS trash binding contract.
package Files.Platform.Macos.Trash is
   --  Return the native macOS trash binding status for this build.
   --
   --  @return Native API binding status.
   function Binding_Status return Files.File_System.Native_API_Binding_Status;

   --  Evaluate native macOS trash support for Request.
   --
   --  @param Request Native trash request to evaluate.
   --  @return Native trash result.
   function Evaluate
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;

   --  Move Request.Path to trash.
   --
   --  @param Request Native trash request to execute.
   --  @return Native trash result.
   function Move
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;
end Files.Platform.Macos.Trash;
