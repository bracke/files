with Ada.Strings.Unbounded;

package body Files.Platform.Macos.Trash is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Native_API_Binding_Status;

   function Binding_Status return Files.File_System.Native_API_Binding_Status is
   begin
      return Files.File_System.Native_API_Not_Target;
   end Binding_Status;

   function Evaluate
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
      pragma Unreferenced (Request);
   begin
      return
        (Supported        => False,
         Attempted        => False,
         Completed        => False,
         Native_Binding_Available => Binding_Status = Files.File_System.Native_API_Binding_Available,
         Native_Binding_Status => Binding_Status,
         Binding_Unit    => To_Unbounded_String ("Files.Platform.Macos.Trash"),
         Desktop_Standard => False,
         Would_Delete     => False,
         Uses_Recycle_Bin => False,
         Adapter_Name     => To_Unbounded_String ("macos.trash"),
         Native_Api_Name  => To_Unbounded_String ("NSFileManager.trashItemAtURL"),
         Operation_Name   => To_Unbounded_String ("move_to_trash"),
         Requires_User_Consent => False,
         Preserves_Metadata    => True,
         Error_Key        => To_Unbounded_String ("error.trash.native_unavailable"));
   end Evaluate;

   function Move
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Evaluate (Request);
   end Move;
end Files.Platform.Macos.Trash;
