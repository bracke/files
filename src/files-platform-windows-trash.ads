with Files.File_System;

--  Windows Recycle Bin binding contract.
package Files.Platform.Windows.Trash is
   --  Return the native Windows trash binding status for this build.
   --
   --  @return Native API binding status.
   function Binding_Status return Files.File_System.Native_API_Binding_Status;

   --  Evaluate native Windows trash support for Request.
   --
   --  @param Request Native trash request to evaluate.
   --  @return Native trash result.
   function Evaluate
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;

   --  Move Request.Path to the Recycle Bin.
   --
   --  @param Request Native trash request to execute.
   --  @return Native trash result.
   function Move
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result;
end Files.Platform.Windows.Trash;
