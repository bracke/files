with Ada.Strings.Unbounded;
with Files.Platform.Macos.Trash;
with Files.Platform.Macos.Volumes;

package body Files.Platform.Macos is
   use Ada.Strings.Unbounded;

   function API_Profile return Files.File_System.Native_Platform_API_Profile is
   begin
      return
        (Adapter               => Files.File_System.Native_Adapter_Macos,
         Trash_Binding_Status  => Files.Platform.Macos.Trash.Binding_Status,
         Volume_Binding_Status => Files.Platform.Macos.Volumes.Binding_Status,
         Trash_API_Name        => To_Unbounded_String ("NSFileManager.trashItemAtURL"),
         Volume_API_Name       => To_Unbounded_String ("NSURLResourceValues+statfs"),
         Trash_Binding_Unit    => To_Unbounded_String ("Files.Platform.Macos.Trash"),
         Volume_Binding_Unit   => To_Unbounded_String ("Files.Platform.Macos.Volumes"),
         Required_Library      => Null_Unbounded_String,
         Required_Framework    => To_Unbounded_String ("Foundation"),
         Current_Target        => False,
         Trash_Can_Execute     => False,
         Volume_Can_Query      => Files.Platform.Macos.Volumes.Can_Query);
   end API_Profile;

   function Native_Locale return String is
   begin
      return "";
   end Native_Locale;

   function Evaluate_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result
   is
   begin
      return Files.Platform.Macos.Trash.Evaluate (Request);
   end Evaluate_Trash;

   function Move_To_Trash
     (Request : Files.File_System.Native_Trash_Request)
      return Files.File_System.Native_Trash_Result is
   begin
      return Files.Platform.Macos.Trash.Move (Request);
   end Move_To_Trash;
end Files.Platform.Macos;
